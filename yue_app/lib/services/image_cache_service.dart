import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// Encrypted local image cache.
///
/// Images are downloaded, XOR-encrypted and stored to the app's private
/// cache directory.  On subsequent loads the encrypted file is read back,
/// decrypted in memory and returned as [Uint8List].
class ImageCacheService {
  static const String _xorKey = 'YueImg@Cache!2024#Sec';
  static const String _cacheDir = 'enc_img_cache';
  static const int _maxMemCacheEntries = 80;

  static ImageCacheService? _instance;
  late final Directory _dir;
  late final Dio _dio;
  // LRU memory cache: insertion-order map, evict oldest when full
  final LinkedHashMap<String, Uint8List> _memCache = LinkedHashMap();

  ImageCacheService._();

  static Future<ImageCacheService> getInstance() async {
    if (_instance == null) {
      _instance = ImageCacheService._();
      final base = await getApplicationCacheDirectory();
      _instance!._dir = Directory('${base.path}/$_cacheDir');
      if (!_instance!._dir.existsSync()) {
        _instance!._dir.createSync(recursive: true);
      }
      _instance!._dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
      ));
    }
    return _instance!;
  }

  void _putMemCache(String url, Uint8List bytes) {
    // Remove and re-insert to maintain LRU order
    _memCache.remove(url);
    _memCache[url] = bytes;
    while (_memCache.length > _maxMemCacheEntries) {
      _memCache.remove(_memCache.keys.first);
    }
  }

  /// Deterministic, URL-safe file name derived from the full image URL.
  static String _fileKey(String url) {
    final bytes = utf8.encode(url);
    // Use two independent FNV-1a hashes for collision resistance
    int h1 = 0x811c9dc5;
    int h2 = 0x01000193;
    for (final b in bytes) {
      h1 ^= b;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 ^= b;
      h2 = (h2 * 0x811c9dc5) & 0xFFFFFFFF;
    }
    // Also encode the full URL in base64url for absolute uniqueness
    final b64 = base64Url.encode(bytes).replaceAll('=', '');
    // Keep hash prefix for quick lookup; b64 ensures uniqueness
    return '${h1.toRadixString(16)}${h2.toRadixString(16)}_$b64';
  }

  File _fileFor(String url) => File('${_dir.path}/${_fileKey(url)}');

  // --- XOR encrypt / decrypt (symmetric) ---

  static Uint8List _xor(Uint8List data) {
    final keyBytes = utf8.encode(_xorKey);
    final out = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      out[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    return out;
  }

  /// Return cached image bytes (decrypted), or `null` if not cached.
  Future<Uint8List?> get(String url) async {
    // 1. Memory cache
    final mem = _memCache[url];
    if (mem != null) {
      // Touch for LRU
      _memCache.remove(url);
      _memCache[url] = mem;
      return mem;
    }

    // 2. Disk cache
    final file = _fileFor(url);
    if (file.existsSync()) {
      try {
        final encrypted = await file.readAsBytes();
        final decrypted = await compute(_xor, Uint8List.fromList(encrypted));
        _putMemCache(url, decrypted);
        return decrypted;
      } catch (_) {
        // Corrupted file – delete and re-download
        try { file.deleteSync(); } catch (_) {}
      }
    }
    return null;
  }

  /// Download, encrypt, persist to disk, then read back from local. Returns decrypted bytes.
  Future<Uint8List?> download(String url) async {
    try {
      final response = await _dio.get<List<int>>(url);
      if (response.data == null) return null;
      final bytes = Uint8List.fromList(response.data!);

      // Encrypt and write to disk first
      final encrypted = await compute(_xor, bytes);
      final file = _fileFor(url);
      await file.writeAsBytes(encrypted, flush: true);

      // Read back from local encrypted file to ensure data is served from disk
      final localEncrypted = await file.readAsBytes();
      final decrypted = await compute(_xor, Uint8List.fromList(localEncrypted));
      _putMemCache(url, decrypted);
      return decrypted;
    } catch (_) {
      return null;
    }
  }

  /// Network-first: try downloading fresh data, save to local, serve from local.
  /// If network fails, fall back to existing local cache.
  Future<Uint8List?> getOrDownload(String url) async {
    // 1. Try network first – download, encrypt, persist, read back from local
    final downloaded = await download(url);
    if (downloaded != null) return downloaded;

    // 2. Network failed – fall back to local cache
    return get(url);
  }
}
