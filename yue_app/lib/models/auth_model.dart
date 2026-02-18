import 'user_model.dart';

class AuthResponse {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final UserModel? user;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
      expiresIn: json['expires_in'] is int ? json['expires_in'] : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

class ApiResponse<T> {
  final int? code;
  final String? message;
  final T? data;

  ApiResponse({this.code, this.message, this.data});
}
