import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../pages/post_detail_page.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailPage(postId: post.id, initialPost: post),
          ),
        );
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cover image
          if (post.coverImage != null && post.coverImage!.isNotEmpty)
            AspectRatio(
              aspectRatio: _getImageAspectRatio(),
              child: Image.network(
                post.coverImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(
                    child: Icon(Icons.image_outlined,
                        size: 32, color: Color(0xFFCCCCCC)),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFF5F5F5),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Content area
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                // Author row
                Row(
                  children: [
                    // Avatar
                    _buildAvatar(),
                    const SizedBox(width: 5),
                    // Username
                    Expanded(
                      child: Text(
                        post.user.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                    // Like count
                    const Icon(
                      Icons.favorite_border,
                      size: 14,
                      color: Color(0xFFCCCCCC),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(post.likeCount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = post.user.avatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEEEEEE),
      ),
      child: const Icon(Icons.person, size: 12, color: Color(0xFFCCCCCC)),
    );
  }

  double _getImageAspectRatio() {
    // Vary aspect ratio based on post id for visual variety in waterfall
    final ratio = post.id % 3;
    switch (ratio) {
      case 0:
        return 3 / 4;
      case 1:
        return 1;
      case 2:
        return 4 / 3;
      default:
        return 3 / 4;
    }
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
