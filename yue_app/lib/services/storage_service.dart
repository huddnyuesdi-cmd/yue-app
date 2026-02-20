import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyUserCenterToken = 'user_center_token';
  static const String _keyCommunityToken = 'community_token';
  static const String _keyCommunityRefreshToken = 'community_refresh_token';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyCommunityUserId = 'community_user_id';
  static const String _keyFollowStatus = 'follow_status_cache';
  static const String _keyCachedPosts = 'cached_posts';
  static const String _keyCachedPostsTime = 'cached_posts_time';
  static const String _keyCachedProfileData = 'cached_profile_data';
  static const String _keyCachedProfileTime = 'cached_profile_time';

  static StorageService? _instance;
  late SharedPreferences _prefs;

  /// In-memory follow status cache for fast reads
  final Map<String, bool> _followCache = {};

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
      _instance!._loadFollowCache();
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

  // Community User ID
  Future<void> setCommunityUserId(int userId) async {
    await _prefs.setInt(_keyCommunityUserId, userId);
  }

  int? getCommunityUserId() {
    return _prefs.getInt(_keyCommunityUserId);
  }

  Future<void> clearCommunityUserId() async {
    await _prefs.remove(_keyCommunityUserId);
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
    await _prefs.remove(_keyCommunityUserId);
    await clearFollowCache();
  }

  // Check if logged in
  bool isLoggedIn() {
    final token = getUserCenterToken();
    return token != null && token.isNotEmpty;
  }

  // --- Follow Status Cache ---

  void _loadFollowCache() {
    final raw = _prefs.getString(_keyFollowStatus);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        _followCache.clear();
        map.forEach((k, v) {
          if (v is bool) _followCache[k] = v;
        });
      } catch (_) {}
    }
  }

  Future<void> _persistFollowCache() async {
    await _prefs.setString(_keyFollowStatus, json.encode(_followCache));
  }

  /// Get cached follow status for a user. Returns null if not cached.
  bool? getFollowStatus(String userId) {
    return _followCache[userId];
  }

  /// Set follow status in cache.
  Future<void> setFollowStatus(String userId, bool isFollowing) async {
    _followCache[userId] = isFollowing;
    await _persistFollowCache();
  }

  // --- Posts Cache ---

  /// Cache posts data as JSON string with timestamp.
  Future<void> setCachedPosts(String key, String postsJson) async {
    await _prefs.setString('${_keyCachedPosts}_$key', postsJson);
    await _prefs.setInt('${_keyCachedPostsTime}_$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached posts if still fresh (within maxAgeMinutes).
  String? getCachedPosts(String key, {int maxAgeMinutes = 5}) {
    final time = _prefs.getInt('${_keyCachedPostsTime}_$key');
    if (time == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - time;
    if (age > maxAgeMinutes * 60 * 1000) return null;
    return _prefs.getString('${_keyCachedPosts}_$key');
  }

  // --- Profile Data Cache ---

  /// Cache profile data as JSON string with timestamp.
  Future<void> setCachedProfileData(String key, String dataJson) async {
    await _prefs.setString('${_keyCachedProfileData}_$key', dataJson);
    await _prefs.setInt('${_keyCachedProfileTime}_$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cached profile data if still fresh (within maxAgeMinutes).
  String? getCachedProfileData(String key, {int maxAgeMinutes = 10}) {
    final time = _prefs.getInt('${_keyCachedProfileTime}_$key');
    if (time == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - time;
    if (age > maxAgeMinutes * 60 * 1000) return null;
    return _prefs.getString('${_keyCachedProfileData}_$key');
  }

  // Clear all auth data
  Future<void> clearFollowCache() async {
    _followCache.clear();
    await _prefs.remove(_keyFollowStatus);
  }
}
