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
  static const String _migrated = '_k_migrated';

  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
      await _instance!._migrateKeys();
    }
    return _instance!;
  }

  // --- Key obfuscation ---

  static String _obfuscateKey(String key) {
    final keyBytes = utf8.encode(_obfuscationKey);
    final inputBytes = utf8.encode(key);
    final result = Uint8List(inputBytes.length);
    for (int i = 0; i < inputBytes.length; i++) {
      result[i] = inputBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return 'k_${base64Url.encode(result)}';
  }

  // Migrate old plaintext keys to obfuscated keys
  Future<void> _migrateKeys() async {
    if (_prefs.getBool(_migrated) == true) return;

    final oldKeys = [
      _keyUserCenterToken,
      _keyCommunityToken,
      _keyCommunityRefreshToken,
      _keyUserProfile,
      _keyCommunityUserId,
      _keyHomeFeedCache,
    ];

    for (final oldKey in oldKeys) {
      final value = _prefs.get(oldKey);
      if (value != null) {
        final newKey = _obfuscateKey(oldKey);
        if (value is String) {
          // Obfuscate plaintext values; keep already-obfuscated ones as-is
          await _prefs.setString(newKey, value.startsWith(_encPrefix) ? value : _obfuscate(value));
        } else if (value is int) {
          await _prefs.setString(newKey, _obfuscate(value.toString()));
        } else if (value is bool) {
          await _prefs.setString(newKey, _obfuscate(value.toString()));
        }
        await _prefs.remove(oldKey);
      }
    }

    // Migrate dynamic-key entries (follow_status_*, post_liked_*, post_collected_*, user_profile_cache_*)
    final allKeys = _prefs.getKeys().toList();
    for (final oldKey in allKeys) {
      if (oldKey.startsWith(_keyFollowStatusPrefix) ||
          oldKey.startsWith(_keyPostLikePrefix) ||
          oldKey.startsWith(_keyPostCollectPrefix) ||
          oldKey.startsWith(_keyUserProfileCachePrefix)) {
        final value = _prefs.get(oldKey);
        if (value != null) {
          final newKey = _obfuscateKey(oldKey);
          if (value is String) {
            await _prefs.setString(newKey, value.startsWith(_encPrefix) ? value : _obfuscate(value));
          } else if (value is bool) {
            await _prefs.setString(newKey, _obfuscate(value.toString()));
          }
          await _prefs.remove(oldKey);
        }
      }
    }

    await _prefs.setBool(_migrated, true);
  }

  // --- Value obfuscation helpers ---

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
    await _prefs.setString(_obfuscateKey(key), _obfuscate(value));
  }

  String? _getObfuscatedString(String key) {
    final stored = _prefs.getString(_obfuscateKey(key));
    if (stored == null) return null;
    try {
      return _deobfuscate(stored);
    } catch (_) {
      return stored; // fallback to raw value
    }
  }

  Future<void> _removeKey(String key) async {
    await _prefs.remove(_obfuscateKey(key));
  }

  Future<void> _setObfuscatedBool(String key, bool value) async {
    await _prefs.setString(_obfuscateKey(key), _obfuscate(value.toString()));
  }

  bool? _getObfuscatedBool(String key) {
    final val = _getObfuscatedString(key);
    if (val == null) return null;
    if (val == 'true') return true;
    if (val == 'false') return false;
    return null;
  }

  Future<void> _setObfuscatedInt(String key, int value) async {
    await _prefs.setString(_obfuscateKey(key), _obfuscate(value.toString()));
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
    await _removeKey(_keyCommunityUserId);
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
    await _removeKey(_keyUserCenterToken);
    await _removeKey(_keyCommunityToken);
    await _removeKey(_keyCommunityRefreshToken);
    await _removeKey(_keyUserProfile);
    await _removeKey(_keyCommunityUserId);
  }

  // Check if logged in
  bool isLoggedIn() {
    final token = getUserCenterToken();
    return token != null && token.isNotEmpty;
  }
}
