import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyUserCenterToken = 'user_center_token';
  static const String _keyCommunityToken = 'community_token';
  static const String _keyCommunityRefreshToken = 'community_refresh_token';
  static const String _keyUserProfile = 'user_profile';

  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // User Center Token
  Future<void> setUserCenterToken(String token) async {
    await _prefs.setString(_keyUserCenterToken, token);
  }

  String? getUserCenterToken() {
    return _prefs.getString(_keyUserCenterToken);
  }

  // Community Token
  Future<void> setCommunityToken(String token) async {
    await _prefs.setString(_keyCommunityToken, token);
  }

  String? getCommunityToken() {
    return _prefs.getString(_keyCommunityToken);
  }

  // Community Refresh Token
  Future<void> setCommunityRefreshToken(String token) async {
    await _prefs.setString(_keyCommunityRefreshToken, token);
  }

  String? getCommunityRefreshToken() {
    return _prefs.getString(_keyCommunityRefreshToken);
  }

  // User Profile (JSON string)
  Future<void> setUserProfile(String profileJson) async {
    await _prefs.setString(_keyUserProfile, profileJson);
  }

  String? getUserProfile() {
    return _prefs.getString(_keyUserProfile);
  }

  // Clear all auth data
  Future<void> clearAll() async {
    await _prefs.remove(_keyUserCenterToken);
    await _prefs.remove(_keyCommunityToken);
    await _prefs.remove(_keyCommunityRefreshToken);
    await _prefs.remove(_keyUserProfile);
  }

  // Check if logged in
  bool isLoggedIn() {
    final token = getUserCenterToken();
    return token != null && token.isNotEmpty;
  }
}
