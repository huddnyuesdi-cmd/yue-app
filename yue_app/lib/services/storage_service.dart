import 'dart:convert';
import 'dart:typed_data';
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

  static const String _obfuscationKey = 'YueM@2024!Secure#Key';
  static const String _encPrefix = 'e:';

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

  // --- Obfuscation helpers ---

  static String _obfuscate(String value) {
    final keyBytes = utf8.encode(_obfuscationKey);
    final valueBytes = utf8.encode(value);
    final result = Uint8List(valueBytes.length);
    for (int i = 0; i < valueBytes.length; i++) {
      result[i] = valueBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return '$_encPrefix${base64Encode(result)}';
  }

  static String _deobfuscate(String stored) {
    if (!stored.startsWith(_encPrefix)) {
      return stored; // plaintext from before obfuscation was added
    }
    final encoded = stored.substring(_encPrefix.length);
    final keyBytes = utf8.encode(_obfuscationKey);
    final encryptedBytes = base64Decode(encoded);
    final result = Uint8List(encryptedBytes.length);
    for (int i = 0; i < encryptedBytes.length; i++) {
      result[i] = encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(result);
  }

  Future<void> _setObfuscatedString(String key, String value) async {
    await _prefs.setString(key, _obfuscate(value));
  }

  String? _getObfuscatedString(String key) {
    final stored = _prefs.getString(key);
    if (stored == null) return null;
    try {
      return _deobfuscate(stored);
    } catch (_) {
      return stored; // fallback to raw value
    }
  }

  Future<void> _setObfuscatedBool(String key, bool value) async {
    await _prefs.setString(key, _obfuscate(value.toString()));
  }

  bool? _getObfuscatedBool(String key) {
    final val = _getObfuscatedString(key);
    if (val == null) return null;
    if (val == 'true') return true;
    if (val == 'false') return false;
    return null;
  }

  Future<void> _setObfuscatedInt(String key, int value) async {
    await _prefs.setString(key, _obfuscate(value.toString()));
  }

  int? _getObfuscatedInt(String key) {
    final val = _getObfuscatedString(key);
    if (val == null) return null;
    return int.tryParse(val);
  }

  // User Center Token
  Future<void> setUserCenterToken(String token) async {
    await _setObfuscatedString(_keyUserCenterToken, token);
  }

  String? getUserCenterToken() {
    return _getObfuscatedString(_keyUserCenterToken);
  }

  // Community Token
  Future<void> setCommunityToken(String token) async {
    await _setObfuscatedString(_keyCommunityToken, token);
  }

  String? getCommunityToken() {
    return _getObfuscatedString(_keyCommunityToken);
  }

  // Community Refresh Token
  Future<void> setCommunityRefreshToken(String token) async {
    await _setObfuscatedString(_keyCommunityRefreshToken, token);
  }

  String? getCommunityRefreshToken() {
    return _getObfuscatedString(_keyCommunityRefreshToken);
  }

  // Community User ID
  Future<void> setCommunityUserId(int userId) async {
    await _setObfuscatedInt(_keyCommunityUserId, userId);
  }

  int? getCommunityUserId() {
    return _getObfuscatedInt(_keyCommunityUserId);
  }

  Future<void> clearCommunityUserId() async {
    await _prefs.remove(_keyCommunityUserId);
  }

  // User Profile (JSON string)
  Future<void> setUserProfile(String profileJson) async {
    await _setObfuscatedString(_keyUserProfile, profileJson);
  }

  String? getUserProfile() {
    return _getObfuscatedString(_keyUserProfile);
  }

  // User Profile Cache (by userId)
  Future<void> setUserProfileCache(String userId, String jsonStr) async {
    await _setObfuscatedString('$_keyUserProfileCachePrefix$userId', jsonStr);
  }

  String? getUserProfileCache(String userId) {
    return _getObfuscatedString('$_keyUserProfileCachePrefix$userId');
  }

  // Home Feed Cache
  Future<void> setHomeFeedCache(String jsonStr) async {
    await _setObfuscatedString(_keyHomeFeedCache, jsonStr);
  }

  String? getHomeFeedCache() {
    return _getObfuscatedString(_keyHomeFeedCache);
  }

  // Follow Status Cache (by userId)
  Future<void> setFollowStatus(String userId, bool isFollowing) async {
    await _setObfuscatedBool('$_keyFollowStatusPrefix$userId', isFollowing);
  }

  bool? getFollowStatus(String userId) {
    return _getObfuscatedBool('$_keyFollowStatusPrefix$userId');
  }

  // Post Like State Cache (by postId)
  Future<void> setPostLiked(int postId, bool liked) async {
    await _setObfuscatedBool('$_keyPostLikePrefix$postId', liked);
  }

  bool? getPostLiked(int postId) {
    return _getObfuscatedBool('$_keyPostLikePrefix$postId');
  }

  // Post Collect State Cache (by postId)
  Future<void> setPostCollected(int postId, bool collected) async {
    await _setObfuscatedBool('$_keyPostCollectPrefix$postId', collected);
  }

  bool? getPostCollected(int postId) {
    return _getObfuscatedBool('$_keyPostCollectPrefix$postId');
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
