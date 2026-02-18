import 'package:flutter/material.dart';
import '../models/post_model.dart';

/// Post card widget for the waterfall grid layout.
/// Displays post image, title, user info, and engagement metrics.
/// Styled like 小红书 (Xiaohongshu) post cards.
class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post image
          Expanded(
            child: _buildImage(),
          ),
          // Post info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                if (post.title != null && post.title!.isNotEmpty)
                  Text(
                    post.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 6),
                // User info and likes
                Row(
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFFEEEEEE),
                      backgroundImage: post.user?.avatar != null &&
                              post.user!.avatar!.isNotEmpty
                          ? NetworkImage(post.user!.avatar!)
                          : null,
                      child: post.user?.avatar == null ||
                              post.user!.avatar!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 12,
                              color: Color(0xFFBBBBBB),
                            )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    // Username
                    Expanded(
                      child: Text(
                        post.user?.nickname ?? '用户',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                    // Likes
                    const Icon(
                      Icons.favorite_border,
                      size: 14,
                      color: Color(0xFF999999),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(post.likesCount ?? 0),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (post.images.isNotEmpty) {
      return Container(
        width: double.infinity,
        color: const Color(0xFFF5F5F5),
        child: Image.network(
          post.images.first,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder();
          },
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          post.type == 2 ? Icons.videocam_outlined : Icons.image_outlined,
          size: 40,
          color: const Color(0xFFCCCCCC),
        ),
      ),
    );
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
