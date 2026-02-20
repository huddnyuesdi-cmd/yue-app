import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../config/layout_config.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
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
  bool _isLoading = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isToggling = false;
  double _followScale = 1.0;
  PostService? _postService;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // Pre-cache PostService instance for faster follow toggle
    PostService.getInstance().then((ps) => _postService = ps);
    // Load follow state from local cache first (instant, no flicker)
    final storage = await StorageService.getInstance();
    final cachedFollow = storage.getFollowStatus(widget.userId);
    if (cachedFollow != null && mounted) {
      setState(() => _isFollowing = cachedFollow);
    }
    await _loadCachedProfile(skipFollowState: cachedFollow != null);
    _loadUserProfile();
  }

  Future<void> _loadCachedProfile({bool skipFollowState = false}) async {
    try {
      final storage = await StorageService.getInstance();
      final cached = storage.getUserProfileCache(widget.userId);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userInfo = data['userInfo'] as Map<String, dynamic>? ?? {};
            _stats = data['stats'] as Map<String, dynamic>? ?? {};
            final postsJson = data['posts'] as List? ?? [];
            _posts = postsJson
                .whereType<Map<String, dynamic>>()
                .map((json) => Post.fromJson(json))
                .toList();
            if (!skipFollowState) {
              _isFollowing = _extractFollowStatus({}, _userInfo);
            }
            _isLoading = false;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveProfileCache() async {
    try {
      final storage = await StorageService.getInstance();
      final data = {
        'userInfo': _userInfo,
        'stats': _stats,
        'posts': _posts.map((p) => p.toJson()).toList(),
      };
      await storage.setUserProfileCache(widget.userId, jsonEncode(data));
    } catch (_) {}
  }

  /// Helper to extract follow status from API response maps.
  bool _extractFollowStatus(Map<String, dynamic> followStatus, Map<String, dynamic> userInfo) {
    // Check followStatus API response first (most authoritative)
    if (followStatus.containsKey('is_following')) return followStatus['is_following'] == true;
    if (followStatus.containsKey('followed')) return followStatus['followed'] == true;
    if (followStatus.containsKey('following')) return followStatus['following'] == true;
    // Fallback to userInfo
    if (userInfo.containsKey('is_following')) return userInfo['is_following'] == true;
    if (userInfo.containsKey('followed')) return userInfo['followed'] == true;
    if (userInfo.containsKey('following')) return userInfo['following'] == true;
    return false;
  }

  Future<void> _loadUserProfile() async {
    try {
      final postService = await PostService.getInstance();

      final results = await Future.wait([
        postService.getUserInfo(widget.userId),
        postService.getUserStats(widget.userId),
        postService.getUserPosts(widget.userId),
        postService.getFollowStatus(widget.userId),
      ]);

      if (mounted) {
        final followStatus = results[3] as Map<String, dynamic>;
        setState(() {
          _userInfo = results[0] as Map<String, dynamic>;
          _stats = results[1] as Map<String, dynamic>;
          _posts = (results[2] as PostListResponse).posts;
          if (!_isToggling) {
            _isFollowing = _extractFollowStatus(followStatus, _userInfo);
          }
          _isLoading = false;
        });
        // Persist follow state locally
        final storage = await StorageService.getInstance();
        await storage.setFollowStatus(widget.userId, _isFollowing);
        _saveProfileCache();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    _isFollowLoading = true;
    _isToggling = true;

    final wasFollowing = _isFollowing;
    // Optimistic update immediately
    setState(() {
      _isFollowing = !wasFollowing;
      _followScale = 0.8;
    });
    // Persist optimistic state locally right away
    StorageService.getInstance().then((s) => s.setFollowStatus(widget.userId, _isFollowing));
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _followScale = 1.08);
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _followScale = 1.0);
    });

    // Release button lock after short debounce so user isn't blocked by API latency
    Future.delayed(const Duration(milliseconds: 350), () {
      _isFollowLoading = false;
    });

    // Fire-and-forget API call - don't block UI
    _performFollowApi(wasFollowing);
  }

  Future<void> _performFollowApi(bool wasFollowing) async {
    try {
      final postService = _postService ?? await PostService.getInstance();
      _postService = postService;
      if (wasFollowing) {
        await postService.unfollowUser(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已取消关注'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await postService.followUser(widget.userId);
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      // If server says already followed/unfollowed, keep current state
      if (!wasFollowing && (msg.contains('已关注') || msg.contains('已经关注') || msg.contains('already'))) {
        if (mounted) setState(() => _isFollowing = true);
        return;
      }
      if (wasFollowing && (msg.contains('未关注') || msg.contains('没有关注') || msg.contains('not following'))) {
        if (mounted) setState(() => _isFollowing = false);
        return;
      }
      // Don't revert on timeout/network errors - keep optimistic state
      if (msg.contains('超时') || msg.contains('timeout') || msg.contains('网络') || msg.contains('连接')) {
        return;
      }
      // Revert only on actual server rejection
      if (mounted) {
        setState(() => _isFollowing = wasFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      _isFollowLoading = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _isToggling = false;
      });
      StorageService.getInstance().then((s) => s.setFollowStatus(widget.userId, _isFollowing));
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
      body: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = LayoutConfig.getGridColumnCount(constraints.maxWidth);
              return CustomScrollView(
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
                  else if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2),
                        ),
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
              );
            },
          ),
    );
  }

  Widget _buildProfileHeader(String nickname, String avatar, String bio, String userId, {String background = '', int verified = 0, String verifiedName = ''}) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bgHeight = (background.isNotEmpty ? 150.0 : 120.0) + statusBarHeight;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final screenWidth = MediaQuery.of(context).size.width;
    final bgCacheWidth = (screenWidth * pixelRatio).toInt();
    final avatarCacheSize = (72 * pixelRatio).toInt();

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
                    cacheWidth: bgCacheWidth,
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
                              cacheWidth: avatarCacheSize,
                              cacheHeight: avatarCacheSize,
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
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isFollowing ? const Color(0xFFF5F5F5) : const Color(0xFFFF2442),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _isFollowing ? '已关注' : '+ 关注',
                          key: ValueKey(_isFollowing),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$followingCount', '关注'),
          _buildStatItem('$followerCount', '粉丝'),
          _buildStatItem('$likeCount', '获赞与收藏'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}
