import 'package:dio/dio.dart';

/// API service for communicating with the backend servers.
///
/// Two base URLs:
/// - Community API (社区): https://xiaoshiliu.yuelk.com/api
/// - User Center (用户中心): https://user.yuelk.com/api
class ApiService {
  static const String communityBaseUrl = 'https://xiaoshiliu.yuelk.com/api';
  static const String userCenterBaseUrl = 'https://user.yuelk.com/api';

  final Dio _communityDio;
  final Dio _userCenterDio;

  String? _accessToken;

  ApiService()
      : _communityDio = Dio(BaseOptions(
          baseUrl: communityBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )),
        _userCenterDio = Dio(BaseOptions(
          baseUrl: userCenterBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _communityDio.interceptors.add(_authInterceptor());
    _userCenterDio.interceptors.add(_authInterceptor());
  }

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null && _accessToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
    );
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  // ===== Community Auth APIs =====

  /// Login with user_id and password on the community server
  Future<Response> login({
    required String userId,
    required String password,
  }) async {
    return _communityDio.post('/auth/login', data: {
      'user_id': userId,
      'password': password,
    });
  }

  /// Register on the community server
  Future<Response> register({
    required String userId,
    required String nickname,
    required String password,
    String? captchaId,
    String? captchaText,
  }) async {
    final data = <String, dynamic>{
      'user_id': userId,
      'nickname': nickname,
      'password': password,
    };
    if (captchaId != null) data['captchaId'] = captchaId;
    if (captchaText != null) data['captchaText'] = captchaText;
    return _communityDio.post('/auth/register', data: data);
  }

  /// Get captcha for registration
  Future<Response> getCaptcha() async {
    return _communityDio.get('/auth/captcha');
  }

  /// Get auth config (check what's available: email, oauth2, etc.)
  Future<Response> getAuthConfig() async {
    return _communityDio.get('/auth/auth-config');
  }

  /// OAuth2 login - redirects to user center for authentication
  /// GET /api/auth/oauth2/login
  Future<Response> getOAuth2LoginUrl() async {
    return _communityDio.get('/auth/oauth2/login',
        options: Options(followRedirects: false, validateStatus: (s) => true));
  }

  /// Exchange OAuth2 token for community JWT
  /// POST /api/auth/oauth2/mobile-token
  /// Supports two modes: user_token or user_profile
  Future<Response> exchangeOAuth2Token({
    String? userToken,
    String? userProfile,
  }) async {
    final data = <String, dynamic>{};
    if (userToken != null) data['user_token'] = userToken;
    if (userProfile != null) data['user_profile'] = userProfile;
    return _communityDio.post('/auth/oauth2/mobile-token', data: data);
  }

  /// Refresh token
  Future<Response> refreshToken(String refreshToken) async {
    return _communityDio.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
  }

  /// Get current user info
  Future<Response> getCurrentUser() async {
    return _communityDio.get('/auth/me');
  }

  /// Logout
  Future<Response> logout() async {
    return _communityDio.post('/auth/logout');
  }

  // ===== User Center APIs =====

  /// Exchange API key for JWT from user center
  Future<Response> userCenterExchangeToken(String apiKey) async {
    return _userCenterDio.post('/user-api/token', data: {
      'api_key': apiKey,
    });
  }

  /// Get user profile from user center
  Future<Response> userCenterGetProfile() async {
    return _userCenterDio.get('/auth/profile');
  }

  // ===== Posts APIs =====

  /// Get recommended posts for waterfall feed
  Future<Response> getRecommendedPosts({int page = 1, int limit = 20}) async {
    return _communityDio.get('/posts/recommended', queryParameters: {
      'page': page,
      'limit': limit,
    });
  }

  /// Get post detail
  Future<Response> getPostDetail(int postId) async {
    return _communityDio.get('/posts/$postId');
  }

  /// Get posts list
  Future<Response> getPosts({int page = 1, int limit = 20}) async {
    return _communityDio.get('/posts', queryParameters: {
      'page': page,
      'limit': limit,
    });
  }
}
