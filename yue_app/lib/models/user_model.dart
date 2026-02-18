import 'dart:convert';

class UserCenterUser {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final String? avatar;
  final double? balance;
  final int? vipLevel;
  final bool? isActive;
  final bool? emailVerified;
  final String? createdAt;

  UserCenterUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatar,
    this.balance,
    this.vipLevel,
    this.isActive,
    this.emailVerified,
    this.createdAt,
  });

  factory UserCenterUser.fromJson(Map<String, dynamic> json) {
    return UserCenterUser(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      vipLevel: json['vip_level'] as int?,
      isActive: json['is_active'] as bool?,
      emailVerified: json['email_verified'] as bool?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'display_name': displayName,
      'avatar': avatar,
      'balance': balance,
      'vip_level': vipLevel,
      'is_active': isActive,
      'email_verified': emailVerified,
      'created_at': createdAt,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserCenterUser.fromJsonString(String jsonString) {
    return UserCenterUser.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

class AuthResponse {
  final String token;
  final UserCenterUser user;

  AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: UserCenterUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class CommunityTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;

  CommunityTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  factory CommunityTokenResponse.fromJson(Map<String, dynamic> json) {
    return CommunityTokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int?,
    );
  }
}

class CaptchaStatus {
  final bool enabled;
  final String? mode;

  CaptchaStatus({required this.enabled, this.mode});

  factory CaptchaStatus.fromJson(Map<String, dynamic> json) {
    return CaptchaStatus(
      enabled: json['enabled'] as bool? ?? false,
      mode: json['mode'] as String?,
    );
  }
}

class CaptchaData {
  final String id;
  final bool enabled;
  final String? target;

  CaptchaData({required this.id, required this.enabled, this.target});

  factory CaptchaData.fromJson(Map<String, dynamic> json) {
    return CaptchaData(
      id: json['id'] as String,
      enabled: json['enabled'] as bool? ?? false,
      target: json['target'] as String?,
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? code;

  ApiResponse({this.success = false, this.data, this.message, this.code});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) {
    final success = json['success'] as bool? ?? (json['code'] == 200);
    final rawData = json['data'];
    T? data;
    if (rawData != null && fromJsonT != null && rawData is Map<String, dynamic>) {
      data = fromJsonT(rawData);
    }
    return ApiResponse(
      success: success,
      data: data,
      message: json['message'] as String?,
      code: json['code'] as int?,
    );
  }
}
