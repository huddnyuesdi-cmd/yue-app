import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/comment_model.dart';
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

  /// Fetch post detail by id.
  Future<Post> getPostDetail(int postId) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/posts/$postId',
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取帖子详情失败');
      }

      final postData = data['data'] as Map<String, dynamic>?;
      if (postData == null) {
        throw Exception('帖子不存在');
      }

      return Post.fromJson(postData);
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Fetch comments for a post.
  Future<List<Comment>> getPostComments(int postId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/posts/$postId/comments',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取评论失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) return [];

      final commentsJson = responseData['list'] as List? ?? responseData['comments'] as List? ?? [];
      return commentsJson
          .whereType<Map<String, dynamic>>()
          .map((json) => Comment.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Toggle like on a post.
  Future<bool> toggleLike(int targetId, {String targetType = 'post'}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.post(
        '/api/likes',
        data: {'target_type': targetType, 'target_id': targetId.toString()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Toggle collect on a post.
  Future<bool> toggleCollect(int postId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.post(
        '/api/posts/$postId/collect',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Add a comment.
  Future<bool> addComment(int postId, String content, {int? parentId}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final body = <String, dynamic>{
        'post_id': postId.toString(),
        'content': content,
      };
      if (parentId != null) {
        body['parent_id'] = parentId.toString();
      }

      final response = await _dio.post(
        '/api/comments',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Delete a comment.
  Future<bool> deleteComment(int commentId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.delete(
        '/api/comments/$commentId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get replies for a comment.
  Future<List<Comment>> getCommentReplies(int commentId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/comments/$commentId/replies',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) return [];

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) return [];

      final commentsJson = responseData['comments'] as List? ?? responseData['list'] as List? ?? [];
      return commentsJson
          .whereType<Map<String, dynamic>>()
          .map((json) => Comment.fromJson(json))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Search posts.
  Future<PostListResponse> searchPosts({
    String? keyword,
    String? tag,
    int page = 1,
    int limit = 20,
  }) async {
    final token = _storage.getCommunityToken();

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }
      if (tag != null && tag.isNotEmpty) {
        queryParams['tag'] = tag;
      }

      final response = await _dio.get(
        '/api/search',
        queryParameters: queryParams,
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '搜索失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['list'] as List? ?? responseData['posts'] as List? ?? [];
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
      _throwDioError(e);
    }
  }

  /// Get hot tags.
  Future<List<Map<String, dynamic>>> getHotTags({int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/api/tags/hot',
        queryParameters: {'limit': limit},
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) return [];

      final tagsData = data['data'];
      if (tagsData is List) {
        return tagsData.whereType<Map<String, dynamic>>().toList();
      }
      if (tagsData is Map<String, dynamic>) {
        final list = tagsData['list'] as List? ?? tagsData['tags'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get user posts.
  Future<PostListResponse> getUserPosts(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/users/$userId/posts',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取用户笔记失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['list'] as List? ?? responseData['posts'] as List? ?? [];
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
      _throwDioError(e);
    }
  }

  /// Get user collections.
  Future<PostListResponse> getUserCollections(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/users/$userId/collections',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取收藏列表失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['list'] as List? ?? responseData['posts'] as List? ?? [];
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
      _throwDioError(e);
    }
  }

  /// Get user likes.
  Future<PostListResponse> getUserLikes(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/users/$userId/likes',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取点赞列表失败');
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['list'] as List? ?? responseData['posts'] as List? ?? [];
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
      _throwDioError(e);
    }
  }

  /// Get user stats.
  Future<Map<String, dynamic>> getUserStats(int userId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/users/$userId/stats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) return {};

      return data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Get notifications list.
  Future<List<Map<String, dynamic>>> getNotifications({int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/notifications',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) return [];

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) {
        final list = responseData['list'] as List? ?? responseData['notifications'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      if (responseData is List) {
        return responseData.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Mark notification as read.
  Future<void> markNotificationRead(int notificationId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) return;

    try {
      await _dio.put(
        '/api/notifications/$notificationId/read',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  /// Mark all notifications as read.
  Future<void> markAllNotificationsRead() async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) return;

    try {
      await _dio.put(
        '/api/notifications/read-all',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  /// Follow/unfollow user.
  Future<bool> toggleFollow(int userId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.post(
        '/api/users/$userId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Unfollow user.
  Future<bool> unfollowUser(int userId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.delete(
        '/api/users/$userId/follow',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get follow status for a user.
  Future<Map<String, dynamic>> getFollowStatus(int userId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) return {};

    try {
      final response = await _dio.get(
        '/api/users/$userId/follow-status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return {};
      return data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Get mutual follows list.
  Future<List<Map<String, dynamic>>> getMutualFollows(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/users/$userId/mutual-follows',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return [];

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) {
        final list = responseData['list'] as List? ?? responseData['users'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      if (responseData is List) {
        return responseData.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Record browsing history.
  Future<bool> recordBrowsingHistory(int postId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await _dio.post(
        '/api/users/history',
        data: {'post_id': postId.toString()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get browsing history.
  Future<PostListResponse> getBrowsingHistory({int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/users/history',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        return PostListResponse(posts: [], pagination: null);
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['posts'] as List? ?? responseData['list'] as List? ?? [];
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
      _throwDioError(e);
    }
  }

  /// Clear all browsing history.
  Future<bool> clearBrowsingHistory() async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.delete(
        '/api/users/history',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Delete a single browsing history item.
  Future<bool> deleteBrowsingHistoryItem(int postId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.delete(
        '/api/users/history/$postId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get user info.
  Future<Map<String, dynamic>> getUserInfo(int userId) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/users/$userId',
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) return {};

      return data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Create a new post.
  Future<bool> createPost({
    required String title,
    String? content,
    List<String>? tags,
    List<String>? imageUrls,
    int type = 1,
  }) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final body = <String, dynamic>{
        'title': title,
        'type': type,
      };

      if (content != null && content.isNotEmpty) {
        body['content'] = content;
      }

      if (tags != null && tags.isNotEmpty) {
        body['tags'] = tags;
      }

      if (imageUrls != null && imageUrls.isNotEmpty) {
        body['images'] = imageUrls.map((url) => {'url': url, 'isFreePreview': true}).toList();
      }

      final response = await _dio.post(
        '/api/posts',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get current authenticated user from community API.
  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '获取用户信息失败');
      }

      return data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Update user profile.
  Future<Map<String, dynamic>> updateUserProfile(int userId, Map<String, dynamic> updates) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.put(
        '/api/users/$userId',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        throw Exception(data['message'] as String? ?? '更新资料失败');
      }

      return data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Change password.
  Future<bool> changePassword(int userId, String currentPassword, String newPassword) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.put(
        '/api/users/$userId/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get following feed posts.
  Future<PostListResponse> getFollowingPosts({int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      return PostListResponse(posts: [], pagination: null);
    }

    try {
      final response = await _dio.get(
        '/api/posts/following',
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200) {
        return PostListResponse(posts: [], pagination: null);
      }

      final responseData = data['data'] as Map<String, dynamic>?;
      if (responseData == null) {
        return PostListResponse(posts: [], pagination: null);
      }

      final postsJson = responseData['posts'] as List? ?? responseData['list'] as List? ?? [];
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
    } catch (_) {
      // Server may return 500 for following feed; gracefully show empty state
      return PostListResponse(posts: [], pagination: null);
    }
  }

  /// Submit onboarding data.
  Future<bool> submitOnboarding({
    String? gender,
    String? birthday,
    List<String>? interests,
  }) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final body = <String, dynamic>{};
      if (gender != null) body['gender'] = gender;
      if (birthday != null) body['birthday'] = birthday;
      if (interests != null) body['interests'] = interests;

      final response = await _dio.post(
        '/api/users/onboarding',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Refresh community token.
  Future<bool> refreshToken() async {
    final refreshToken = _storage.getCommunityRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;

      if (code != 200 || data['data'] == null) {
        return false;
      }

      final tokenData = data['data'] as Map<String, dynamic>;
      final newAccessToken = tokenData['access_token'] as String?;
      final newRefreshToken = tokenData['refresh_token'] as String?;

      if (newAccessToken != null) {
        await _storage.setCommunityToken(newAccessToken);
      }
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.setCommunityRefreshToken(newRefreshToken);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get user's following list.
  Future<List<Map<String, dynamic>>> getFollowing(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/users/$userId/following',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return [];

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) {
        final list = responseData['list'] as List? ?? responseData['users'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      if (responseData is List) {
        return responseData.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get user's followers list.
  Future<List<Map<String, dynamic>>> getFollowers(int userId, {int page = 1, int limit = 20}) async {
    final token = _storage.getCommunityToken();

    try {
      final response = await _dio.get(
        '/api/users/$userId/followers',
        queryParameters: {'page': page, 'limit': limit},
        options: token != null && token.isNotEmpty
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return [];

      final responseData = data['data'];
      if (responseData is Map<String, dynamic>) {
        final list = responseData['list'] as List? ?? responseData['users'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      if (responseData is List) {
        return responseData.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Delete a post.
  Future<bool> deletePost(int postId) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.delete(
        '/api/posts/$postId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get privacy settings.
  Future<Map<String, dynamic>> getPrivacySettings() async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.get(
        '/api/users/privacy-settings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return {};
      return data['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Update privacy settings.
  Future<bool> updatePrivacySettings(Map<String, dynamic> settings) async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) {
      throw Exception('请先登录');
    }

    try {
      final response = await _dio.put(
        '/api/users/privacy-settings',
        data: settings,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      return data['code'] == 200;
    } on DioException catch (e) {
      _throwDioError(e);
    }
  }

  /// Get toolbar items configuration.
  Future<List<Map<String, dynamic>>> getToolbarItems() async {
    final token = _storage.getCommunityToken();
    if (token == null || token.isEmpty) return [];

    try {
      final response = await _dio.get(
        '/api/users/toolbar',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final data = response.data as Map<String, dynamic>;
      final code = data['code'] as int?;
      if (code != 200) return [];

      final responseData = data['data'];
      if (responseData is List) {
        return responseData.whereType<Map<String, dynamic>>().toList();
      }
      if (responseData is Map<String, dynamic>) {
        final list = responseData['list'] as List? ?? responseData['items'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Never _throwDioError(DioException e) {
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
