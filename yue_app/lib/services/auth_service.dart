import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class AuthService {
  late final Dio _userCenterDio;
  late final Dio _communityDio;
  late final StorageService _storage;

  static AuthService? _instance;

  AuthService._();

  static Future<AuthService> getInstance() async {
    if (_instance == null) {
      _instance = AuthService._();
      _instance!._storage = await StorageService.getInstance();
      _instance!._userCenterDio = Dio(BaseOptions(
        baseUrl: ApiConfig.userCenterBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
      _instance!._communityDio = Dio(BaseOptions(
        baseUrl: ApiConfig.communityBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
    }
    return _instance!;
  }

  /// Login with email (or username) and password.
  /// Returns the AuthResponse on success.
  Future<AuthResponse> login(String email, String password, {String? captchaId}) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
      };

      if (captchaId != null) {
        body['captcha_id'] = captchaId;
      }

      final response = await _userCenterDio.post('/auth/login', data: body);

      final apiResp = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AuthResponse.fromJson,
      );

      if (!apiResp.success || apiResp.data == null) {
        throw Exception(apiResp.message ?? '登录失败');
      }

      final authData = apiResp.data!;

      // Store user center token and profile
      await _storage.setUserCenterToken(authData.token);
      await _storage.setUserProfile(authData.user.toJsonString());

      // Exchange for community token
      await _tryExchangeCommunityToken(authData.token);

      return authData;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Register a new account.
  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
    String? captchaId,
    int? captchaPosition,
  }) async {
    try {
      final body = <String, dynamic>{
        'email': email,
        'username': username,
        'password': password,
        'display_name': displayName,
      };

      if (captchaId != null) {
        body['captcha_id'] = captchaId;
        body['captcha_position'] = captchaPosition ?? 0;
      }

      final response = await _userCenterDio.post('/auth/register', data: body);

      final apiResp = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        AuthResponse.fromJson,
      );

      if (!apiResp.success || apiResp.data == null) {
        throw Exception(apiResp.message ?? '注册失败');
      }

      final authData = apiResp.data!;

      // Store user center token and profile
      await _storage.setUserCenterToken(authData.token);
      await _storage.setUserProfile(authData.user.toJsonString());

      // Exchange for community token
      await _tryExchangeCommunityToken(authData.token);

      return authData;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get captcha status.
  Future<CaptchaStatus> getCaptchaStatus() async {
    try {
      final response = await _userCenterDio.get('/captcha/status');
      final apiResp = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        CaptchaStatus.fromJson,
      );
      return apiResp.data ?? CaptchaStatus(enabled: false);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Generate a captcha.
  Future<CaptchaData> generateCaptcha() async {
    try {
      final response = await _userCenterDio.post('/captcha/generate');
      final apiResp = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        CaptchaData.fromJson,
      );
      if (apiResp.data == null) {
        throw Exception('获取验证码失败');
      }
      return apiResp.data!;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Verify a captcha.
  /// For slide mode, sends answer.x; for other modes, sends position.
  Future<bool> verifyCaptcha(String id, int position, {String mode = 'slide'}) async {
    try {
      final body = <String, dynamic>{'id': id};

      if (mode == 'slide') {
        body['answer'] = {'x': position};
      } else {
        body['position'] = position;
      }

      final response = await _userCenterDio.post('/captcha/verify', data: body);
      final data = response.data as Map<String, dynamic>;
      return data['success'] as bool? ?? false;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Exchange user center token for community token.
  Future<CommunityTokenResponse> exchangeCommunityToken(
    String userCenterToken,
  ) async {
    try {
      final response = await _communityDio.post(
        '/api/auth/oauth2/mobile-token',
        data: {'user_token': userCenterToken},
      );

      final data = response.data as Map<String, dynamic>;
      final success = data['code'] == 200;
      if (!success || data['data'] == null) {
        throw Exception(data['message'] as String? ?? '社区令牌交换失败');
      }

      final tokenResp = CommunityTokenResponse.fromJson(
        data['data'] as Map<String, dynamic>,
      );

      await _storage.setCommunityToken(tokenResp.accessToken);
      await _storage.setCommunityRefreshToken(tokenResp.refreshToken);

      return tokenResp;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Try to exchange community token, but don't fail if it doesn't work.
  Future<void> _tryExchangeCommunityToken(String userCenterToken) async {
    try {
      await exchangeCommunityToken(userCenterToken);
    } catch (_) {
      // Community token exchange is optional; user may need to register
      // on the community platform separately.
    }
  }

  /// Logout and clear all stored tokens.
  Future<void> logout() async {
    await _storage.clearAll();
  }

  /// Check if the user is logged in.
  bool isLoggedIn() {
    return _storage.isLoggedIn();
  }

  /// Get stored user center token.
  String? getUserCenterToken() {
    return _storage.getUserCenterToken();
  }

  /// Get stored community token.
  String? getCommunityToken() {
    return _storage.getCommunityToken();
  }

  /// Get stored user profile.
  UserCenterUser? getStoredUser() {
    final profileJson = _storage.getUserProfile();
    if (profileJson == null) return null;
    try {
      return UserCenterUser.fromJsonString(profileJson);
    } catch (_) {
      return null;
    }
  }

  /// Handle Dio errors and return a user-friendly exception.
  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return Exception(message);
        }
      }
      return Exception('请求失败 (${e.response?.statusCode})');
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('网络连接超时，请检查网络');
      case DioExceptionType.connectionError:
        return Exception('无法连接服务器，请检查网络');
      default:
        return Exception('网络请求失败，请稍后重试');
    }
  }
}
