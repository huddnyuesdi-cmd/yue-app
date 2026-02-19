class CommentUser {
  final int id;
  final String userId;
  final String nickname;
  final String? avatar;

  CommentUser({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatar,
  });

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }
}

class Comment {
  final int id;
  final String content;
  final int postId;
  final String userId;
  final int? parentId;
  final String? createdAt;
  final CommentUser? user;
  final int likeCount;
  final bool liked;
  final int replyCount;
  List<Comment> replies;

  Comment({
    required this.id,
    required this.content,
    required this.postId,
    required this.userId,
    this.parentId,
    this.createdAt,
    this.user,
    this.likeCount = 0,
    this.liked = false,
    this.replyCount = 0,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final repliesList = <Comment>[];
    if (json['replies'] != null && json['replies'] is List) {
      for (final reply in json['replies'] as List) {
        if (reply is Map<String, dynamic>) {
          repliesList.add(Comment.fromJson(reply));
        }
      }
    }

    CommentUser? user;
    if (json['user'] != null && json['user'] is Map<String, dynamic>) {
      user = CommentUser.fromJson(json['user'] as Map<String, dynamic>);
    } else if (json['nickname'] != null || json['user_avatar'] != null) {
      user = CommentUser(
        id: json['user_auto_id'] as int? ?? 0,
        userId: json['user_display_id'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        avatar: json['user_avatar'] as String?,
      );
    }

    final rawUserId = json['user_id'];
    final userIdStr = rawUserId is String ? rawUserId : (rawUserId != null ? rawUserId.toString() : '');

    return Comment(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      postId: json['post_id'] as int? ?? 0,
      userId: userIdStr,
      parentId: json['parent_id'] as int?,
      createdAt: json['created_at'] as String?,
      user: user,
      likeCount: json['like_count'] as int? ?? 0,
      liked: json['liked'] as bool? ?? false,
      replyCount: json['reply_count'] as int? ?? 0,
      replies: repliesList,
    );
  }
}
