import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// In-memory image cache with network download.
///
/// Images are downloaded from the network and kept in an LRU memory cache.
/// No files are written to disk.
class ImageCacheService {
  static const int _maxMemCacheEntries = 80;

  static ImageCacheService? _instance;
  late final Dio _dio;
  final LinkedHashMap<String, Uint8List> _memCache = LinkedHashMap();

  ImageCacheService._();

  static Future<ImageCacheService> getInstance() async {
    if (_instance == null) {
      _instance = ImageCacheService._();
      _instance!._dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.bytes,
      ));
    }
    return _instance!;
  }

  void _putMemCache(String url, Uint8List bytes) {
    _memCache.remove(url);
    _memCache[url] = bytes;
    while (_memCache.length > _maxMemCacheEntries) {
      _memCache.remove(_memCache.keys.first);
    }
  }

  /// Return cached image bytes, or `null` if not in memory.
  Uint8List? get(String url) {
    final mem = _memCache[url];
    if (mem != null) {
      _memCache.remove(url);
      _memCache[url] = mem;
      return mem;
    }
    return null;
  }

  /// Download from network and cache in memory. Returns bytes.
  Future<Uint8List?> download(String url) async {
    try {
      final response = await _dio.get<List<int>>(url);
      if (response.data == null) return null;
      final bytes = Uint8List.fromList(response.data!);
      _putMemCache(url, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Memory-first: serve from memory cache if available,
  /// otherwise download from network and cache.
  Future<Uint8List?> getOrDownload(String url) async {
    final cached = get(url);
    if (cached != null) return cached;
    return download(url);
  }
}
