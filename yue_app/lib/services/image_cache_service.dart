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

  static ImageCacheService? _instance;
  late final Directory _dir;
  late final Dio _dio;
  final Map<String, Uint8List> _memCache = {};

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

  /// Deterministic, URL-safe file name derived from the image URL.
  String _fileKey(String url) {
    final bytes = utf8.encode(url);
    // Simple FNV-1a-like hash to produce a short hex name
    int hash = 0x811c9dc5;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // Append base64url of the URL tail for extra uniqueness
    final tail = url.length > 40 ? url.substring(url.length - 40) : url;
    final suffix = base64Url.encode(utf8.encode(tail)).replaceAll('=', '');
    return '${hash.toRadixString(16)}_$suffix';
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
    if (mem != null) return mem;

    // 2. Disk cache
    final file = _fileFor(url);
    if (file.existsSync()) {
      try {
        final encrypted = await file.readAsBytes();
        final decrypted = await compute(_xor, Uint8List.fromList(encrypted));
        _memCache[url] = decrypted;
        return decrypted;
      } catch (_) {
        // Corrupted file – delete and re-download
        try { file.deleteSync(); } catch (_) {}
      }
    }
    return null;
  }

  /// Download, encrypt and cache. Returns decrypted bytes.
  Future<Uint8List?> download(String url) async {
    try {
      final response = await _dio.get<List<int>>(url);
      if (response.data == null) return null;
      final bytes = Uint8List.fromList(response.data!);

      // Store in memory
      _memCache[url] = bytes;

      // Encrypt and write to disk (fire-and-forget)
      compute(_xor, bytes).then((encrypted) {
        _fileFor(url).writeAsBytes(encrypted, flush: true).catchError((_) => File(''));
      });

      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Get from cache or download.
  Future<Uint8List?> getOrDownload(String url) async {
    final cached = await get(url);
    if (cached != null) return cached;
    return download(url);
  }
}
