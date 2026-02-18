import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/post_service.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  final Post? initialPost;

  const PostDetailPage({super.key, required this.postId, this.initialPost});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isCommentsLoading = true;
  String? _error;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadPostDetail();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPostDetail() async {
    try {
      final postService = await PostService.getInstance();
      final post = await postService.getPostDetail(widget.postId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final postService = await PostService.getInstance();
      final comments = await postService.getPostComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isCommentsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCommentsLoading = false);
      }
    }
  }

  Future<void> _handleLike() async {
    if (_post == null) return;
    try {
      final postService = await PostService.getInstance();
      await postService.toggleLike(_post!.id);
      await _loadPostDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _handleCollect() async {
    if (_post == null) return;
    try {
      final postService = await PostService.getInstance();
      await postService.toggleCollect(_post!.id);
      await _loadPostDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _handleComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _post == null) return;

    try {
      final postService = await PostService.getInstance();
      await postService.addComment(_post!.id, content);
      _commentController.clear();
      FocusScope.of(context).unfocus();
      await _loadComments();
      await _loadPostDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final date = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 30) return '${diff.inDays}天前';
      return '${date.month}-${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: _post != null
            ? Row(
                children: [
                  _buildSmallAvatar(_post!.user.avatar),
                  const SizedBox(width: 8),
                  Text(
                    _post!.user.nickname,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                  ),
                ],
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF333333), size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading && _post == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : _error != null && _post == null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF999999))))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image carousel
                            if (_post!.images.isNotEmpty) _buildImageCarousel(),
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post!.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  if (_post!.content != null && _post!.content!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _post!.content!,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF666666),
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                  // Tags
                                  if (_post!.tags.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: _post!.tags
                                          .map((tag) => Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF0F0),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '#${tag.name}',
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(
                                    _formatTime(_post!.createdAt),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF0F0F0)),
                            // Comments section
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Text(
                                    '评论 ${_post!.commentCount}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isCommentsLoading)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)),
                                  ),
                                ),
                              )
                            else if (_comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text('暂无评论，来说两句吧~', style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
                                ),
                              )
                            else
                              ..._comments.map((comment) => _buildCommentItem(comment)),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                    // Bottom bar
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildImageCarousel() {
    final images = _post!.images;
    return SizedBox(
      height: MediaQuery.of(context).size.width,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                images[index].url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFCCCCCC))),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentImageIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _currentImageIndex ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSmallAvatar(comment.user?.avatar, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.user?.nickname ?? '匿名用户',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.4),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(comment.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    ),
                    const SizedBox(width: 16),
                    if (comment.likeCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.favorite_border, size: 12, color: Color(0xFFBBBBBB)),
                          const SizedBox(width: 2),
                          Text(
                            '${comment.likeCount}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                          ),
                        ],
                      ),
                  ],
                ),
                // Replies
                if (comment.replies.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: comment.replies
                          .map((reply) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                                    children: [
                                      TextSpan(
                                        text: '${reply.user?.nickname ?? "匿名用户"}: ',
                                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                                      ),
                                      TextSpan(text: reply.content),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                decoration: const InputDecoration(
                  hintText: '说点什么...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _handleComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: _post?.liked == true ? Icons.favorite : Icons.favorite_border,
            label: '${_post?.likeCount ?? 0}',
            color: _post?.liked == true ? const Color(0xFFFF6B6B) : const Color(0xFF999999),
            onTap: _handleLike,
          ),
          _buildActionButton(
            icon: _post?.collected == true ? Icons.star : Icons.star_border,
            label: '${_post?.collectCount ?? 0}',
            color: _post?.collected == true ? const Color(0xFFFFB800) : const Color(0xFF999999),
            onTap: _handleCollect,
          ),
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: '${_post?.commentCount ?? 0}',
            color: const Color(0xFF999999),
            onTap: () => _commentFocusNode.requestFocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAvatar(String? avatarUrl, {double size = 28}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultSmallAvatar(size),
        ),
      );
    }
    return _defaultSmallAvatar(size);
  }

  Widget _defaultSmallAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEEEEEE),
      ),
      child: Icon(Icons.person, size: size * 0.6, color: const Color(0xFFCCCCCC)),
    );
  }
}
