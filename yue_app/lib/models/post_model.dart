import 'dart:convert';

import 'user_model.dart';

class PostModel {
  final int? id;
  final String? title;
  final String? content;
  final List<String> images;
  final int? type; // 1: image, 2: video
  final String? userId;
  final int? likesCount;
  final int? commentsCount;
  final int? collectsCount;
  final String? createdAt;
  final UserModel? user;

  PostModel({
    this.id,
    this.title,
    this.content,
    this.images = const [],
    this.type,
    this.userId,
    this.likesCount,
    this.commentsCount,
    this.collectsCount,
    this.createdAt,
    this.user,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic imagesData) {
      if (imagesData == null) return [];
      if (imagesData is List) {
        return imagesData.map((e) => e.toString()).toList();
      }
      if (imagesData is String) {
        try {
          // Try parsing as JSON string array
          final decoded = jsonDecode(imagesData);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
        return [imagesData];
      }
      return [];
    }

    return PostModel(
      id: json['id'] is int ? json['id'] : null,
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      images: parseImages(json['images']),
      type: json['type'] is int ? json['type'] : null,
      userId: json['user_id']?.toString(),
      likesCount: json['likes_count'] is int ? json['likes_count'] : 0,
      commentsCount: json['comments_count'] is int ? json['comments_count'] : 0,
      collectsCount: json['collects_count'] is int ? json['collects_count'] : 0,
      createdAt: json['created_at']?.toString(),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}
