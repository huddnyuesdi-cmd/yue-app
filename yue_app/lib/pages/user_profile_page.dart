import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  final String? nickname;
  final String? avatar;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.nickname,
    this.avatar,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic> _userInfo = {};
  Map<String, dynamic> _stats = {};
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final postService = await PostService.getInstance();

      final results = await Future.wait([
        postService.getUserInfo(widget.userId),
        postService.getUserStats(widget.userId),
        postService.getUserPosts(widget.userId),
      ]);

      if (mounted) {
        setState(() {
          _userInfo = results[0] as Map<String, dynamic>;
          _stats = results[1] as Map<String, dynamic>;
          _posts = (results[2] as PostListResponse).posts;
          _isFollowing = _userInfo['is_following'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final postService = await PostService.getInstance();
      await postService.toggleFollow(widget.userId);
      setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _userInfo['nickname'] as String? ?? widget.nickname ?? '';
    final avatar = _userInfo['avatar'] as String? ?? widget.avatar ?? '';
    final bio = _userInfo['bio'] as String? ?? '';
    final userId = _userInfo['user_id'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF222222), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          nickname,
          style: const TextStyle(fontSize: 16, color: Color(0xFF222222), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildProfileHeader(nickname, avatar, bio, userId)),
                SliverToBoxAdapter(child: _buildStatsRow()),
                if (_posts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(8),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childCount: _posts.length,
                      itemBuilder: (context, index) => PostCard(post: _posts[index]),
                    ),
                  )
                else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFDDDDDD)),
                          SizedBox(height: 12),
                          Text('暂无笔记', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(String nickname, String avatar, String bio, String userId) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFFF5F5F5),
                  child: avatar.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatar,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 36, color: Color(0xFFCCCCCC)),
                          ),
                        )
                      : const Icon(Icons.person, size: 36, color: Color(0xFFCCCCCC)),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isFollowing ? const Color(0xFFF5F5F5) : const Color(0xFFFF2442),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isFollowing ? '已关注' : '+ 关注',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isFollowing ? const Color(0xFF999999) : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              nickname,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
            ),
          ),
          if (userId.isNotEmpty) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ID: $userId',
                style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              ),
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bio,
                style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final postCount = _stats['post_count'] as int? ?? _stats['posts_count'] as int? ?? _posts.length;
    final followingCount = _stats['following_count'] as int? ?? 0;
    final followerCount = _stats['follower_count'] as int? ?? _stats['followers_count'] as int? ?? 0;
    final likeCount = _stats['like_count'] as int? ?? _stats['likes_count'] as int? ?? _stats['total_likes'] as int? ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('$postCount', '笔记'),
          Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
          _buildStatItem('$followingCount', '关注'),
          Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
          _buildStatItem('$followerCount', '粉丝'),
          Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
          _buildStatItem('$likeCount', '获赞'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }
}
