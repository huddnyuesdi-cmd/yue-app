import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/post_model.dart';
import 'storage_service.dart';

class PostService {
  late final Dio _dio;
  late final StorageService _storage;

  static PostService? _instance;

  PostService._();

  static Future<PostService> getInstance() async {
    if (_instance == null) {
      _instance = PostService._();
      _instance!._storage = await StorageService.getInstance();
      _instance!._dio = Dio(BaseOptions(
        baseUrl: ApiConfig.communityBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
    }
    return _instance!;
  }

  /// Fetch recommended posts with pagination.
  Future<PostListResponse> getRecommendedPosts({
    int page = 1,
    int limit = 20,
  }) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/posts/recommended',
        queryParameters: {
          'page': page,
          'limit': limit,
          'debug': false,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取推荐内容失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['posts'] as List? ?? [];
      final posts = postsJson
          .whereType<Map<String, dynamic>>()
          .map((json) => Post.fromJson(json))
          .toList();

      PostPagination? pagination;
      if (responseData['pagination'] != null) {
        pagination = PostPagination.fromJson(
          responseData['pagination'] as Map<String, dynamic>,
        );
      }

      return PostListResponse(posts: posts, pagination: pagination);
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String?;
          if (message != null && message.isNotEmpty) {
            throw Exception(message);
          }
        }
        throw Exception('请求失败 (${e.response?.statusCode})');
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception('网络连接超时，请检查网络');
        case DioExceptionType.connectionError:
          throw Exception('无法连接服务器，请检查网络');
        default:
          throw Exception('网络请求失败，请稍后重试');
      }
    }
  }
}

class PostPagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PostPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PostPagination.fromJson(Map<String, dynamic> json) {
    return PostPagination(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      pages: json['pages'] as int? ?? 0,
    );
  }
}

class PostListResponse {
  final List<Post> posts;
  final PostPagination? pagination;

  PostListResponse({required this.posts, this.pagination});
}
