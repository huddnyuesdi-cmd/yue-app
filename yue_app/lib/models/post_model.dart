class PostUser {
  final int id;
  final String userId;
  final String nickname;
  final String? avatar;
  final int? verified;
  final String? verifiedName;

  PostUser({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatar,
    this.verified,
    this.verifiedName,
  });

  factory PostUser.fromPostJson(Map<String, dynamic> json) {
    // Support both flat post-level fields and nested user object
    final userObj = json['user'] as Map<String, dynamic>?;

    final id = json['author_auto_id'] as int?
        ?? userObj?['id'] as int?
        ?? 0;

    final userId = json['author_account'] as String?
        ?? userObj?['user_id'] as String?
        ?? json['user_id']?.toString()
        ?? '';

    final nickname = json['nickname'] as String?
        ?? json['author'] as String?
        ?? userObj?['nickname'] as String?
        ?? '';

    final avatar = json['user_avatar'] as String?
        ?? json['avatar'] as String?
        ?? userObj?['avatar'] as String?;

    final verified = json['verified'] as int?
        ?? userObj?['verified'] as int?;

    final verifiedName = json['verified_name'] as String?
        ?? userObj?['verified_name'] as String?;

    return PostUser(
      id: id,
      userId: userId,
      nickname: nickname,
      avatar: avatar,
      verified: verified,
      verifiedName: verifiedName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_auto_id': id,
      'author_account': userId,
      'nickname': nickname,
      'avatar': avatar,
      'verified': verified,
      'verified_name': verifiedName,
    };
  }
}

class PostImage {
  final String url;
  final bool isFreePreview;

  PostImage({required this.url, this.isFreePreview = true});

  factory PostImage.fromJson(Map<String, dynamic> json) {
    return PostImage(
      url: json['url'] as String? ?? '',
      isFreePreview: json['isFreePreview'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'isFreePreview': isFreePreview,
    };
  }
}

class PostTag {
  final int id;
  final String name;

  PostTag({required this.id, required this.name});

  factory PostTag.fromJson(Map<String, dynamic> json) {
    return PostTag(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class Post {
  final int id;
  final int userId;
  final String title;
  final String? content;
  final int type;
  final int viewCount;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final String? createdAt;
  final String? image;
  final List<PostImage> images;
  final List<PostTag> tags;
  final bool liked;
  final bool collected;
  final PostUser user;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.type = 1,
    this.viewCount = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.createdAt,
    this.image,
    this.images = const [],
    this.tags = const [],
    this.liked = false,
    this.collected = false,
    required this.user,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final imagesList = <PostImage>[];
    if (json['images'] != null && json['images'] is List) {
      for (final img in json['images'] as List) {
        if (img is Map<String, dynamic>) {
          imagesList.add(PostImage.fromJson(img));
        }
      }
    }

    final tagsList = <PostTag>[];
    if (json['tags'] != null && json['tags'] is List) {
      for (final tag in json['tags'] as List) {
        if (tag is Map<String, dynamic>) {
          tagsList.add(PostTag.fromJson(tag));
        }
      }
    }

    return Post(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      type: json['type'] as int? ?? 1,
      viewCount: json['view_count'] as int? ?? json['views_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? json['likes_count'] as int? ?? 0,
      collectCount: json['collect_count'] as int? ?? json['collects_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? json['comments_count'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      image: json['image'] as String?,
      images: imagesList,
      tags: tagsList,
      liked: json['liked'] as bool? ?? false,
      collected: json['collected'] as bool? ?? false,
      user: PostUser.fromPostJson(json),
    );
  }

  String? get coverImage {
    if (images.isNotEmpty) return images.first.url;
    return image;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'type': type,
      'view_count': viewCount,
      'like_count': likeCount,
      'collect_count': collectCount,
      'comment_count': commentCount,
      'created_at': createdAt,
      'image': image,
      'images': images.map((i) => i.toJson()).toList(),
      'tags': tags.map((t) => t.toJson()).toList(),
      'liked': liked,
      'collected': collected,
      'author_auto_id': user.id,
      'author_account': user.userId,
      'nickname': user.nickname,
      'avatar': user.avatar,
      'verified': user.verified,
      'verified_name': user.verifiedName,
    };
  }
}
