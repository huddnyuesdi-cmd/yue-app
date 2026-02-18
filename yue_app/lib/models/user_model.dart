class UserModel {
  final String? userId;
  final String? nickname;
  final String? avatar;
  final String? bio;
  final String? location;
  final int? verified;
  final String? gender;
  final String? background;

  UserModel({
    this.userId,
    this.nickname,
    this.avatar,
    this.bio,
    this.location,
    this.verified,
    this.gender,
    this.background,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id']?.toString(),
      nickname: json['nickname']?.toString(),
      avatar: json['avatar']?.toString(),
      bio: json['bio']?.toString(),
      location: json['location']?.toString(),
      verified: json['verified'] is int ? json['verified'] : null,
      gender: json['gender']?.toString(),
      background: json['background']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'nickname': nickname,
      'avatar': avatar,
      'bio': bio,
      'location': location,
      'verified': verified,
      'gender': gender,
      'background': background,
    };
  }
}
