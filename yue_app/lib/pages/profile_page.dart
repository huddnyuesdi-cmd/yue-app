import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../config/layout_config.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/storage_service.dart';
import '../widgets/post_card.dart';
import '../widgets/verified_badge.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserCenterUser? _user;
  Map<String, dynamic> _stats = {};
  List<Post> _posts = [];
  List<Post> _collections = [];
  List<Post> _likes = [];
  bool _isLoadingPosts = false;
  bool _isLoadingCollections = false;
  bool _isLoadingLikes = false;
  int _communityUserId = 0;
  String? _communityNickname;
  String? _communityAvatar;
  String? _communityBio;
  String? _communityUsername;
  String? _communityBackground;
  int _communityVerified = 0;
  String? _communityVerifiedName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    switch (_tabController.index) {
      case 0:
        if (_posts.isEmpty) _loadPosts();
        break;
      case 1:
        if (_collections.isEmpty) _loadCollections();
        break;
      case 2:
        if (_likes.isEmpty) _loadLikes();
        break;
    }
  }

  Future<void> _loadUser() async {
    final authService = await AuthService.getInstance();
    final user = authService.getStoredUser();
    if (mounted) {
      setState(() => _user = user);
    }
    if (user != null) {
      await _loadCommunityProfile(user);
    }
  }

  Future<void> _loadCommunityProfile(UserCenterUser user) async {
    try {
      final postService = await PostService.getInstance();
      
      // Use /api/auth/me to get the real community user
      final communityUser = await postService.getCurrentUser();
      final rawId = communityUser['id'];
      final autoId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
      
      if (autoId != null && autoId > 0) {
        _communityUserId = autoId;
      } else {
        _communityUserId = user.id;
      }

      // Extract display user_id for API calls (backend resolves by user_id)
      _communityUsername = communityUser['user_id']?.toString();

      // Store community user info for other pages
      if (communityUser.isNotEmpty) {
        final storage = await StorageService.getInstance();
        await storage.setCommunityUserId(_communityUserId);
      }

      final displayId = _communityUsername ?? _communityUserId.toString();
      final stats = await postService.getUserStats(displayId);
      if (mounted) {
        setState(() {
          _stats = stats;
          // Update display info from community profile if available
          _communityNickname = communityUser['nickname'] as String?;
          _communityAvatar = communityUser['avatar'] as String?;
          _communityBio = communityUser['bio'] as String?;
          _communityBackground = communityUser['background'] as String?;
          _communityVerified = communityUser['verified'] as int? ?? 0;
          _communityVerifiedName = communityUser['verified_name'] as String?;
        });
      }
      _loadPosts();
      _loadCollections();
      _loadLikes();
    } catch (_) {
      _communityUserId = user.id;
      _loadPosts();
      _loadCollections();
      _loadLikes();
    }
  }

  String get _displayUserId => _communityUsername ?? _communityUserId.toString();

  Future<void> _loadPosts() async {
    if (_isLoadingPosts || _communityUserId == 0) return;
    setState(() => _isLoadingPosts = true);

    try {
      final postService = await PostService.getInstance();
      final response = await postService.getUserPosts(_displayUserId);
      if (mounted) {
        setState(() {
          _posts = response.posts;
          _isLoadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadCollections() async {
    if (_isLoadingCollections || _communityUserId == 0) return;
    setState(() => _isLoadingCollections = true);

    try {
      final postService = await PostService.getInstance();
      final response = await postService.getUserCollections(_displayUserId);
      if (mounted) {
        setState(() {
          _collections = response.posts;
          _isLoadingCollections = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCollections = false);
    }
  }

  Future<void> _loadLikes() async {
    if (_isLoadingLikes || _communityUserId == 0) return;
    setState(() => _isLoadingLikes = true);

    try {
      final postService = await PostService.getInstance();
      final response = await postService.getUserLikes(_displayUserId);
      if (mounted) {
        setState(() {
          _likes = response.posts;
          _isLoadingLikes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLikes = false);
    }
  }

  Future<void> _refreshAll() async {
    if (_user != null) {
      await _loadCommunityProfile(_user!);
    } else {
      await _loadUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFF222222),
      child: NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStats()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF222222),
                unselectedLabelColor: const Color(0xFF999999),
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 15),
                indicatorColor: const Color(0xFFFF2442),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '笔记'),
                  Tab(text: '收藏'),
                  Tab(text: '点赞'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostGrid(_posts, _isLoadingPosts),
          _buildPostGrid(_collections, _isLoadingCollections),
          _buildPostGrid(_likes, _isLoadingLikes),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final baseHeight = (_communityBackground != null && _communityBackground!.isNotEmpty) ? 150.0 : 120.0;
    final bgHeight = baseHeight + statusBarHeight;
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
              if (_communityBackground != null && _communityBackground!.isNotEmpty)
                SizedBox(
                  height: bgHeight,
                  width: double.infinity,
                  child: Image.network(
                    _communityBackground!,
                    fit: BoxFit.cover,
                    cacheWidth: bgCacheWidth,
                    errorBuilder: (_, __, ___) => Container(
                      height: bgHeight,
                      color: const Color(0xFFF0F0F0),
                    ),
                  ),
                )
              else
                Container(height: bgHeight, width: double.infinity, color: const Color(0xFFF0F0F0)),
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
                    child: (_communityAvatar != null && _communityAvatar!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              _communityAvatar!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              cacheWidth: avatarCacheSize,
                              cacheHeight: avatarCacheSize,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 36,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                          )
                        : (_user?.avatar != null && _user!.avatar!.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  _user!.avatar!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  cacheWidth: avatarCacheSize,
                                  cacheHeight: avatarCacheSize,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 36,
                                    color: Color(0xFFCCCCCC),
                                  ),
                                ),
                              )
                            : const Icon(Icons.person, size: 36, color: Color(0xFFCCCCCC)),
                  ),
                ),
              ),
              // Action buttons positioned at bottom-right
              Positioned(
                right: 20,
                bottom: -28,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EditProfilePage(
                            userId: _communityUserId,
                            nickname: _communityNickname,
                            avatar: _communityAvatar,
                            bio: _communityBio,
                          )),
                        );
                        if (result == true) {
                          _loadUser();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF333333),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('编辑资料', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SettingsPage(communityUserId: _communityUserId)),
                        );
                      },
                      child: const Icon(Icons.settings_outlined, size: 22, color: Color(0xFF666666)),
                    ),
                  ],
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
                        _communityNickname ?? _user?.displayName ?? '用户',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_communityVerified > 0)
                      VerifiedBadge(verified: _communityVerified, size: 16),
                  ],
                ),
                if (_communityVerified > 0 && _communityVerifiedName != null && _communityVerifiedName!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _communityVerifiedName!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1D9BF0)),
                  ),
                ] else ...[
                  const SizedBox(height: 3),
                  Text(
                    _communityUsername != null && _communityUsername!.isNotEmpty
                        ? '@$_communityUsername'
                        : '@${_user?.username ?? ''}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                  ),
                ],
                if (_communityBio != null && _communityBio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _communityBio!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

  Widget _buildStats() {
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
          _buildDivider(),
          _buildStatItem('$followerCount', '粉丝'),
          _buildDivider(),
          _buildStatItem('$likeCount', '获赞与收藏'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFEEEEEE),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }

  Widget _buildPostGrid(List<Post> posts, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2),
        ),
      );
    }

    if (posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFDDDDDD)),
            SizedBox(height: 12),
            Text('暂无内容', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = LayoutConfig.getGridColumnCount(constraints.maxWidth);
        return MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
