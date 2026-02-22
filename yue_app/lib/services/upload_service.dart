import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

/// Configuration returned by the chunk upload config endpoint.
class ChunkUploadConfig {
  final int chunkSize;
  final int maxFileSize;

  ChunkUploadConfig({required this.chunkSize, required this.maxFileSize});

  factory ChunkUploadConfig.fromJson(Map<String, dynamic> json) {
    return ChunkUploadConfig(
      chunkSize: json['chunkSize'] as int? ?? 2 * 1024 * 1024,
      maxFileSize: json['maxFileSize'] as int? ?? 500 * 1024 * 1024,
    );
  }
}

/// Progress callback: (uploadedChunks, totalChunks)
typedef ChunkProgressCallback = void Function(int uploaded, int total);

/// Represents a video upload draft that can be resumed.
class VideoUploadDraft {
  final String filePath;
  final String identifier;
  final String filename;
  final int totalChunks;
  final int chunkSize;
  final List<int> uploadedChunks;
  final String? title;
  final String? content;
  final List<String>? tags;

  VideoUploadDraft({
    required this.filePath,
    required this.identifier,
    required this.filename,
    required this.totalChunks,
    required this.chunkSize,
    required this.uploadedChunks,
    this.title,
    this.content,
    this.tags,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'identifier': identifier,
        'filename': filename,
        'totalChunks': totalChunks,
        'chunkSize': chunkSize,
        'uploadedChunks': uploadedChunks,
        'title': title,
        'content': content,
        'tags': tags,
      };

  factory VideoUploadDraft.fromJson(Map<String, dynamic> json) {
    return VideoUploadDraft(
      filePath: json['filePath'] as String,
      identifier: json['identifier'] as String,
      filename: json['filename'] as String,
      totalChunks: json['totalChunks'] as int,
      chunkSize: json['chunkSize'] as int,
      uploadedChunks:
          (json['uploadedChunks'] as List).map((e) => e as int).toList(),
      title: json['title'] as String?,
      content: json['content'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList(),
    );
  }
}

class UploadService {
  late final Dio _dio;
  late final StorageService _storage;

  static UploadService? _instance;

  UploadService._();

  static Future<UploadService> getInstance() async {
    if (_instance == null) {
      _instance = UploadService._();
      _instance!._storage = await StorageService.getInstance();
      _instance!._dio = Dio(BaseOptions(
        baseUrl: ApiConfig.communityBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
    }
    return _instance!;
  }

  String? _getToken() {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }
    return token;
  }

  /// Upload a single image file.
  /// Returns the uploaded image URL.
  Future<String> uploadImage(String filePath) async {
    final token = _getToken();

    final file = File(filePath);
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await _dio.post(
      '/api/upload/single',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '图片上传失败');
    }

    final url = (data['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('图片上传失败：未返回URL');
    }
    return url;
  }

  /// Upload multiple images.
  /// Returns a list of uploaded image URLs.
  Future<List<String>> uploadMultipleImages(List<String> filePaths) async {
    final token = _getToken();

    final files = <MapEntry<String, MultipartFile>>[];
    for (final path in filePaths) {
      final fileName = path.split('/').last;
      files.add(MapEntry(
        'files',
        await MultipartFile.fromFile(path, filename: fileName),
      ));
    }

    final formData = FormData();
    formData.files.addAll(files);

    final response = await _dio.post(
      '/api/upload/multiple',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '图片批量上传失败');
    }

    final responseData = data['data'];
    if (responseData is Map<String, dynamic>) {
      final urls = responseData['urls'];
      if (urls is List) {
        return urls.map((e) => e.toString()).toList();
      }
    }
    if (responseData is List) {
      return responseData
          .map((e) => (e is Map<String, dynamic> ? e['url'] : e).toString())
          .toList();
    }
    throw Exception('图片批量上传失败：未返回URL');
  }

  /// Upload a single video file (non-chunked, for small videos).
  /// Returns the uploaded video URL.
  Future<String> uploadVideo(String filePath) async {
    final token = _getToken();

    final file = File(filePath);
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final response = await _dio.post(
      '/api/upload/video',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '视频上传失败');
    }

    final url = (data['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('视频上传失败：未返回URL');
    }
    return url;
  }

  /// Get chunk upload configuration from the server.
  Future<ChunkUploadConfig> getChunkConfig() async {
    final token = _getToken();

    final response = await _dio.get(
      '/api/upload/chunk/config',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '获取分片配置失败');
    }

    return ChunkUploadConfig.fromJson(
        data['data'] as Map<String, dynamic>? ?? {});
  }

  /// Verify whether a chunk has already been uploaded (supports resumable upload).
  Future<bool> verifyChunk({
    required String identifier,
    required int chunkNumber,
    String? fileMd5,
  }) async {
    final token = _getToken();

    final queryParams = <String, dynamic>{
      'identifier': identifier,
      'chunkNumber': chunkNumber.toString(),
    };
    if (fileMd5 != null) {
      queryParams['md5'] = fileMd5;
    }

    final response = await _dio.get(
      '/api/upload/chunk/verify',
      queryParameters: queryParams,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final data = response.data as Map<String, dynamic>;
    return data['code'] == 200;
  }

  /// Upload a single chunk.
  Future<bool> uploadChunk({
    required String identifier,
    required int chunkNumber,
    required int totalChunks,
    required String filename,
    required String chunkFilePath,
  }) async {
    final token = _getToken();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(chunkFilePath),
      'identifier': identifier,
      'chunkNumber': chunkNumber.toString(),
      'totalChunks': totalChunks.toString(),
      'filename': filename,
    });

    final response = await _dio.post(
      '/api/upload/chunk',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        },
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    return data['code'] == 200;
  }

  /// Merge all uploaded chunks into the final video file.
  /// Returns the merged video URL.
  Future<String> mergeChunks({
    required String identifier,
    required int totalChunks,
    required String filename,
  }) async {
    final token = _getToken();

    final response = await _dio.post(
      '/api/upload/chunk/merge',
      data: {
        'identifier': identifier,
        'totalChunks': totalChunks.toString(),
        'filename': filename,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '合并分片失败');
    }

    final url = (data['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('合并分片失败：未返回URL');
    }
    return url;
  }

  /// Merge chunks for images.
  /// Returns the merged image URL.
  Future<String> mergeImageChunks({
    required String identifier,
    required int totalChunks,
    required String filename,
    String? watermark,
    String? watermarkOpacity,
  }) async {
    final token = _getToken();

    final body = <String, dynamic>{
      'identifier': identifier,
      'totalChunks': totalChunks.toString(),
      'filename': filename,
    };
    if (watermark != null) body['watermark'] = watermark;
    if (watermarkOpacity != null) body['watermarkOpacity'] = watermarkOpacity;

    final response = await _dio.post(
      '/api/upload/chunk/merge/image',
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    final data = response.data as Map<String, dynamic>;
    if (data['code'] != 200) {
      throw Exception(data['message'] as String? ?? '合并图片分片失败');
    }

    final url = (data['data'] as Map<String, dynamic>?)?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('合并图片分片失败：未返回URL');
    }
    return url;
  }

  /// Compute MD5 hash of a file.
  Future<String> _computeFileMd5(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  /// Generate a unique identifier for a file based on its name, size, and last modified time.
  Future<String> generateIdentifier(File file) async {
    final stat = await file.stat();
    final raw = '${file.path}-${stat.size}-${stat.modified.millisecondsSinceEpoch}';
    return md5.convert(utf8.encode(raw)).toString();
  }

  /// Upload a large video using chunked upload with resumable support.
  /// [onProgress] reports (uploadedChunks, totalChunks).
  /// If the upload is interrupted, call [saveVideoDraft] to persist state.
  /// Returns the merged video URL on completion.
  Future<String> uploadVideoChunked({
    required String filePath,
    ChunkProgressCallback? onProgress,
    VideoUploadDraft? resumeDraft,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('视频文件不存在');
    }

    final fileSize = await file.length();
    final filename = file.path.split('/').last;

    // Get chunk config from server
    final config = await getChunkConfig();

    if (fileSize > config.maxFileSize) {
      throw Exception(
          '视频文件过大，最大允许${(config.maxFileSize / 1024 / 1024).round()}MB');
    }

    final chunkSize = config.chunkSize;
    final totalChunks = (fileSize / chunkSize).ceil();
    final identifier =
        resumeDraft?.identifier ?? await generateIdentifier(file);
    final fileMd5 = await _computeFileMd5(file);

    // Determine which chunks are already uploaded (for resumable upload)
    final uploadedChunks = <int>{};
    if (resumeDraft != null) {
      uploadedChunks.addAll(resumeDraft.uploadedChunks);
    }

    // Verify each chunk with the server
    for (int i = 1; i <= totalChunks; i++) {
      if (uploadedChunks.contains(i)) continue;
      final verified =
          await verifyChunk(identifier: identifier, chunkNumber: i, fileMd5: fileMd5);
      if (verified) {
        uploadedChunks.add(i);
      }
    }

    onProgress?.call(uploadedChunks.length, totalChunks);

    // Upload remaining chunks
    final raf = await file.open(mode: FileMode.read);
    try {
      for (int i = 1; i <= totalChunks; i++) {
        if (uploadedChunks.contains(i)) continue;

        final start = (i - 1) * chunkSize;
        final end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
        final chunkLength = end - start;

        // Read chunk bytes
        await raf.setPosition(start);
        final chunkBytes = await raf.read(chunkLength);

        // Write chunk to a temp file
        final tempDir = Directory.systemTemp;
        final tempFile =
            File('${tempDir.path}/chunk_${identifier}_$i.tmp');
        await tempFile.writeAsBytes(chunkBytes);

        try {
          final success = await uploadChunk(
            identifier: identifier,
            chunkNumber: i,
            totalChunks: totalChunks,
            filename: filename,
            chunkFilePath: tempFile.path,
          );

          if (!success) {
            throw Exception('分片 $i/$totalChunks 上传失败');
          }

          uploadedChunks.add(i);
          onProgress?.call(uploadedChunks.length, totalChunks);
        } finally {
          // Clean up temp chunk file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } finally {
      await raf.close();
    }

    // All chunks uploaded, merge them
    final videoUrl = await mergeChunks(
      identifier: identifier,
      totalChunks: totalChunks,
      filename: filename,
    );

    // Clear draft on success
    await clearVideoDraft();

    return videoUrl;
  }

  /// Upload a large image using chunked upload.
  /// Returns the merged image URL.
  Future<String> uploadImageChunked({
    required String filePath,
    ChunkProgressCallback? onProgress,
    String? watermark,
    String? watermarkOpacity,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('图片文件不存在');
    }

    final fileSize = await file.length();
    final filename = file.path.split('/').last;

    final config = await getChunkConfig();
    final chunkSize = config.chunkSize;
    final totalChunks = (fileSize / chunkSize).ceil();
    final identifier = await generateIdentifier(file);

    final uploadedChunks = <int>{};

    // Upload chunks
    final raf = await file.open(mode: FileMode.read);
    try {
      for (int i = 1; i <= totalChunks; i++) {
        final start = (i - 1) * chunkSize;
        final end = (start + chunkSize > fileSize) ? fileSize : start + chunkSize;
        final chunkLength = end - start;

        await raf.setPosition(start);
        final chunkBytes = await raf.read(chunkLength);

        final tempDir = Directory.systemTemp;
        final tempFile =
            File('${tempDir.path}/chunk_${identifier}_$i.tmp');
        await tempFile.writeAsBytes(chunkBytes);

        try {
          final success = await uploadChunk(
            identifier: identifier,
            chunkNumber: i,
            totalChunks: totalChunks,
            filename: filename,
            chunkFilePath: tempFile.path,
          );

          if (!success) {
            throw Exception('图片分片 $i/$totalChunks 上传失败');
          }

          uploadedChunks.add(i);
          onProgress?.call(uploadedChunks.length, totalChunks);
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } finally {
      await raf.close();
    }

    // Merge chunks
    return mergeImageChunks(
      identifier: identifier,
      totalChunks: totalChunks,
      filename: filename,
      watermark: watermark,
      watermarkOpacity: watermarkOpacity,
    );
  }

  /// Save a video upload draft for resumable upload.
  Future<void> saveVideoDraft(VideoUploadDraft draft) async {
    final json = jsonEncode(draft.toJson());
    await _storage.setVideoDraft(json);
  }

  /// Load a previously saved video upload draft.
  Future<VideoUploadDraft?> loadVideoDraft() async {
    final json = _storage.getVideoDraft();
    if (json == null || json.isEmpty) return null;
    try {
      return VideoUploadDraft.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clear the saved video upload draft.
  Future<void> clearVideoDraft() async {
    await _storage.clearVideoDraft();
  }

  /// Smart upload: Use chunked upload for large files, direct upload for small files.
  /// [chunkThreshold] is the file size threshold to switch to chunked upload (default 5MB).
  Future<String> smartUploadVideo({
    required String filePath,
    int chunkThreshold = 5 * 1024 * 1024,
    ChunkProgressCallback? onProgress,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    if (fileSize <= chunkThreshold) {
      return uploadVideo(filePath);
    }

    // Check for existing draft
    final draft = await loadVideoDraft();
    if (draft != null && draft.filePath == filePath) {
      return uploadVideoChunked(
        filePath: filePath,
        onProgress: onProgress,
        resumeDraft: draft,
      );
    }

    return uploadVideoChunked(
      filePath: filePath,
      onProgress: onProgress,
    );
  }

  /// Smart upload for images: Use chunked upload for large images, direct for small.
  Future<String> smartUploadImage({
    required String filePath,
    int chunkThreshold = 5 * 1024 * 1024,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    if (fileSize <= chunkThreshold) {
      return uploadImage(filePath);
    }
    return uploadImageChunked(filePath: filePath);
  }

  /// Create a draft snapshot of the current upload progress for resuming later.
  Future<VideoUploadDraft> createDraftSnapshot({
    required String filePath,
    required String identifier,
    required String filename,
    required int totalChunks,
    required int chunkSize,
    required List<int> uploadedChunks,
    String? title,
    String? content,
    List<String>? tags,
  }) async {
    final draft = VideoUploadDraft(
      filePath: filePath,
      identifier: identifier,
      filename: filename,
      totalChunks: totalChunks,
      chunkSize: chunkSize,
      uploadedChunks: uploadedChunks,
      title: title,
      content: content,
      tags: tags,
    );
    await saveVideoDraft(draft);
    return draft;
  }
}
