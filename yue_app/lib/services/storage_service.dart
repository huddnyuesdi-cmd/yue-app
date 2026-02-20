import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyUserCenterToken = 'user_center_token';
  static const String _keyCommunityToken = 'community_token';
  static const String _keyCommunityRefreshToken = 'community_refresh_token';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyCommunityUserId = 'community_user_id';
  static const String _keyUserProfileCachePrefix = 'user_profile_cache_';
  static const String _keyHomeFeedCache = 'home_feed_cache';
  static const String _keyFollowStatusPrefix = 'follow_status_';
  static const String _keyPostLikePrefix = 'post_liked_';
  static const String _keyPostCollectPrefix = 'post_collected_';

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

  // User Profile Cache (by userId)
  Future<void> setUserProfileCache(String userId, String jsonStr) async {
    await _prefs.setString('$_keyUserProfileCachePrefix$userId', jsonStr);
  }

  String? getUserProfileCache(String userId) {
    return _prefs.getString('$_keyUserProfileCachePrefix$userId');
  }

  // Home Feed Cache
  Future<void> setHomeFeedCache(String jsonStr) async {
    await _prefs.setString(_keyHomeFeedCache, jsonStr);
  }

  String? getHomeFeedCache() {
    return _prefs.getString(_keyHomeFeedCache);
  }

  // Follow Status Cache (by userId)
  Future<void> setFollowStatus(String userId, bool isFollowing) async {
    await _prefs.setBool('$_keyFollowStatusPrefix$userId', isFollowing);
  }

  bool? getFollowStatus(String userId) {
    final key = '$_keyFollowStatusPrefix$userId';
    if (_prefs.containsKey(key)) return _prefs.getBool(key);
    return null;
  }

  // Post Like State Cache (by postId)
  Future<void> setPostLiked(int postId, bool liked) async {
    await _prefs.setBool('$_keyPostLikePrefix$postId', liked);
  }

  bool? getPostLiked(int postId) {
    final key = '$_keyPostLikePrefix$postId';
    if (_prefs.containsKey(key)) return _prefs.getBool(key);
    return null;
  }

  // Post Collect State Cache (by postId)
  Future<void> setPostCollected(int postId, bool collected) async {
    await _prefs.setBool('$_keyPostCollectPrefix$postId', collected);
  }

  bool? getPostCollected(int postId) {
    final key = '$_keyPostCollectPrefix$postId';
    if (_prefs.containsKey(key)) return _prefs.getBool(key);
    return null;
  }

  // Clear all auth data
  Future<void> clearAll() async {
    await _prefs.remove(_keyUserCenterToken);
    await _prefs.remove(_keyCommunityToken);
    await _prefs.remove(_keyCommunityRefreshToken);
    await _prefs.remove(_keyUserProfile);
    await _prefs.remove(_keyCommunityUserId);
  }

  // Check if logged in
  bool isLoggedIn() {
    final token = getUserCenterToken();
    return token != null && token.isNotEmpty;
  }
}
