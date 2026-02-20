import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../config/layout_config.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';
import '../widgets/verified_badge.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
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
  bool _isFollowLoading = false;
  double _followScale = 1.0;

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
          _isFollowing = _userInfo['is_following'] as bool?
              ?? _userInfo['followed'] as bool?
              ?? false;
          _isLoading = false;
        });
      }

      // Also check follow status via dedicated API
      _loadFollowStatus();
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshProfile() async {
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
          _isFollowing = _userInfo['is_following'] as bool?
              ?? _userInfo['followed'] as bool?
              ?? false;
        });
      }
      _loadFollowStatus();
    } catch (_) {}
  }

  Future<void> _loadFollowStatus() async {
    try {
      final postService = await PostService.getInstance();
      final status = await postService.getFollowStatus(widget.userId);
      if (mounted && status.isNotEmpty) {
        final following = status['is_following'] as bool?
            ?? status['following'] as bool?
            ?? status['followed'] as bool?
            ?? false;
        setState(() => _isFollowing = following);
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    _isFollowLoading = true;

    final wasFollowing = _isFollowing;
    // Optimistic update with scale animation
    setState(() {
      _isFollowing = !wasFollowing;
      _followScale = 0.85;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _followScale = 1.0);
    });

    try {
      final postService = await PostService.getInstance();
      if (wasFollowing) {
        await postService.unfollowUser(widget.userId);
      } else {
        await postService.toggleFollow(widget.userId);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // If trying to follow but server says already followed, keep the followed state
      if (!wasFollowing && (msg.contains('已关注') || msg.contains('already'))) {
        if (mounted) {
          setState(() => _isFollowing = true);
        }
        _isFollowLoading = false;
        return;
      }
      // Revert on other failures
      if (mounted) {
        setState(() => _isFollowing = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      _isFollowLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _userInfo['nickname'] as String? ?? widget.nickname ?? '';
    final avatar = _userInfo['avatar'] as String? ?? widget.avatar ?? '';
    final bio = _userInfo['bio'] as String? ?? '';
    final userId = _userInfo['user_id'] as String? ?? '';
    final background = _userInfo['background'] as String? ?? '';
    final verified = _userInfo['verified'] as int? ?? 0;
    final verifiedName = _userInfo['verified_name'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2))
          : LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = LayoutConfig.getGridColumnCount(constraints.maxWidth);
                return RefreshIndicator(
                  onRefresh: _refreshProfile,
                  color: const Color(0xFF222222),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildProfileHeader(nickname, avatar, bio, userId, background: background, verified: verified, verifiedName: verifiedName)),
                      SliverToBoxAdapter(child: _buildStatsRow()),
                      if (_posts.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.all(8),
                          sliver: SliverMasonryGrid.count(
                            crossAxisCount: crossAxisCount,
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
              },
            ),
    );
  }

  Widget _buildProfileHeader(String nickname, String avatar, String bio, String userId, {String background = '', int verified = 0, String verifiedName = ''}) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bgHeight = (background.isNotEmpty ? 150.0 : 120.0) + statusBarHeight;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Background + avatar overlap using Stack
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Background image
              if (background.isNotEmpty)
                SizedBox(
                  height: bgHeight,
                  width: double.infinity,
                  child: Image.network(
                    background,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: bgHeight,
                      width: double.infinity,
                      color: const Color(0xFFF0F0F0),
                    ),
                  ),
                )
              else
                Container(height: bgHeight, width: double.infinity, color: const Color(0xFFF0F0F0)),
              // Back button on background top-left
              Positioned(
                left: 8,
                top: MediaQuery.of(context).padding.top + 4,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
              ),
              // Avatar positioned to overlap background bottom
              Positioned(
                left: 20,
                bottom: -36,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
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
              ),
              // Follow button positioned at bottom-right
              Positioned(
                right: 20,
                bottom: -24,
                child: GestureDetector(
                  onTap: _toggleFollow,
                  child: AnimatedScale(
                    scale: _followScale,
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
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
                ),
              ),
            ],
          ),
          // Space for the avatar part that extends below the background
          const SizedBox(height: 44),
          // User info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verified > 0)
                      VerifiedBadge(verified: verified, size: 16),
                  ],
                ),
                if (verified > 0 && verifiedName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    verifiedName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1D9BF0)),
                  ),
                ] else if (userId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'ID: $userId',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _statValue(dynamic val) {
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    if (val is double) return val.toInt();
    return 0;
  }

  Widget _buildStatsRow() {
    final svFollowCount = _statValue(_stats['follow_count']);
    final svFollowingCount = _statValue(_stats['following_count']);
    final svFansCount = _statValue(_stats['fans_count']);
    final svFollowerCount = _statValue(_stats['follower_count']);
    final svFollowersCount = _statValue(_stats['followers_count']);
    final svLikesAndCollects = _statValue(_stats['likes_and_collects']);
    final svLikeCount = _statValue(_stats['like_count']);
    final svLikesCount = _statValue(_stats['likes_count']);
    final svTotalLikes = _statValue(_stats['total_likes']);

    final followingCount = svFollowCount > 0 ? svFollowCount : svFollowingCount;
    final followerCount = svFansCount > 0 ? svFansCount : svFollowerCount > 0 ? svFollowerCount : svFollowersCount;
    final likeCount = svLikesAndCollects > 0 ? svLikesAndCollects : svLikeCount > 0 ? svLikeCount : svLikesCount > 0 ? svLikesCount : svTotalLikes;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('$followingCount', '关注'),
          Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
          _buildStatItem('$followerCount', '粉丝'),
          Container(width: 1, height: 24, color: const Color(0xFFEEEEEE)),
          _buildStatItem('$likeCount', '获赞与收藏'),
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
