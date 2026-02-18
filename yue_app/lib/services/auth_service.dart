import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Auth service handles login, registration, token management,
/// and OAuth2 flow between community and user center.
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  final ApiService _apiService;
  UserModel? _currentUser;

  AuthService(this._apiService);

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _apiService.accessToken != null;

  /// Initialize auth state from stored tokens on app start.
  /// Tries to restore session, and if a token exists, fetches current user.
  Future<bool> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token != null && token.isNotEmpty) {
      _apiService.setAccessToken(token);
      try {
        // Verify token is still valid by fetching user info
        final response = await _apiService.getCurrentUser();
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final userData = data['data'];
            if (userData is Map<String, dynamic>) {
              _currentUser = UserModel.fromJson(userData);
              return true;
            }
          }
        }
      } catch (e) {
        // Token expired or invalid, try refresh
        final refreshToken = prefs.getString(_refreshTokenKey);
        if (refreshToken != null) {
          return await _refreshToken(refreshToken);
        }
        // Clear invalid tokens
        await _clearTokens();
      }
    }
    return false;
  }

  /// Login with user_id and password (native community login)
  Future<AuthResponse> login({
    required String userId,
    required String password,
  }) async {
    try {
      final response = await _apiService.login(
        userId: userId,
        password: password,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final code = data['code'];
        if (code == 200) {
          final responseData = data['data'] as Map<String, dynamic>?;
          if (responseData != null) {
            final authResponse = AuthResponse.fromJson(responseData);
            if (authResponse.accessToken != null) {
              await _saveTokens(
                authResponse.accessToken!,
                authResponse.refreshToken,
              );
              _apiService.setAccessToken(authResponse.accessToken);
              // Fetch user info
              await _fetchCurrentUser();
            }
            return authResponse;
          }
        } else {
          throw Exception(data['message'] ?? '登录失败');
        }
      }
      throw Exception('登录失败');
    } catch (e) {
      rethrow;
    }
  }

  /// Register a new account on the community
  Future<AuthResponse> register({
    required String userId,
    required String nickname,
    required String password,
    String? captchaId,
    String? captchaText,
  }) async {
    try {
      final response = await _apiService.register(
        userId: userId,
        nickname: nickname,
        password: password,
        captchaId: captchaId,
        captchaText: captchaText,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final code = data['code'];
        if (code == 200) {
          final responseData = data['data'] as Map<String, dynamic>?;
          if (responseData != null) {
            final authResponse = AuthResponse.fromJson(responseData);
            if (authResponse.accessToken != null) {
              await _saveTokens(
                authResponse.accessToken!,
                authResponse.refreshToken,
              );
              _apiService.setAccessToken(authResponse.accessToken);
              await _fetchCurrentUser();
            }
            return authResponse;
          }
        } else {
          throw Exception(data['message'] ?? '注册失败');
        }
      }
      throw Exception('注册失败');
    } catch (e) {
      rethrow;
    }
  }

  /// OAuth2 flow: exchange user center token for community JWT.
  ///
  /// The flow:
  /// 1. User logs into user center (user.yuelk.com) and gets a user_token
  /// 2. This token is sent to community's /api/auth/oauth2/mobile-token
  /// 3. Community validates with user center and returns community JWT
  Future<AuthResponse> exchangeOAuth2Token(String userToken) async {
    try {
      final response = await _apiService.exchangeOAuth2Token(
        userToken: userToken,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final code = data['code'];
        if (code == 200) {
          final responseData = data['data'] as Map<String, dynamic>?;
          if (responseData != null) {
            final authResponse = AuthResponse.fromJson(responseData);
            if (authResponse.accessToken != null) {
              await _saveTokens(
                authResponse.accessToken!,
                authResponse.refreshToken,
              );
              _apiService.setAccessToken(authResponse.accessToken);
              await _fetchCurrentUser();
            }
            return authResponse;
          }
        } else {
          throw Exception(data['message'] ?? 'OAuth2换取令牌失败');
        }
      }
      throw Exception('OAuth2换取令牌失败');
    } catch (e) {
      rethrow;
    }
  }

  /// Logout and clear tokens
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {
      // Ignore logout API errors
    }
    _currentUser = null;
    _apiService.setAccessToken(null);
    await _clearTokens();
  }

  // ===== Private Methods =====

  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await _apiService.refreshToken(refreshToken);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['code'] == 200) {
          final responseData = data['data'] as Map<String, dynamic>?;
          if (responseData != null) {
            final authResponse = AuthResponse.fromJson(responseData);
            if (authResponse.accessToken != null) {
              await _saveTokens(
                authResponse.accessToken!,
                authResponse.refreshToken,
              );
              _apiService.setAccessToken(authResponse.accessToken);
              await _fetchCurrentUser();
              return true;
            }
          }
        }
      }
    } catch (_) {
      // Refresh failed
    }
    await _clearTokens();
    return false;
  }

  Future<void> _fetchCurrentUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final userData = data['data'];
          if (userData is Map<String, dynamic>) {
            _currentUser = UserModel.fromJson(userData);
          }
        }
      }
    } catch (_) {
      // Silently fail - user info is optional
    }
  }

  Future<void> _saveTokens(
      String accessToken, String? refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
  }
}
