import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/post_card.dart';
import 'login_page.dart';

/// Home page with waterfall (瀑布流) layout showing recommended posts.
/// UI inspired by 小红书 (Xiaohongshu) style.
class HomePage extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const HomePage({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _currentPage = 1;
    _posts.clear();
    _hasMore = true;
    _loadPosts();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final response = await widget.apiService.getRecommendedPosts(
        page: _currentPage,
        limit: _pageSize,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final postsData = data['data'];
          List<dynamic>? postsList;

          if (postsData is Map<String, dynamic>) {
            postsList = postsData['list'] as List<dynamic>?;
          } else if (postsData is List) {
            postsList = postsData;
          }

          if (postsList != null) {
            final newPosts = postsList
                .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
                .toList();

            setState(() {
              _posts.addAll(newPosts);
              _currentPage++;
              _hasMore = newPosts.length >= _pageSize;
            });
          } else {
            setState(() => _hasMore = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: ${e.toString().replaceFirst("Exception: ", "")}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _posts.clear();
    _hasMore = true;
    await _loadPosts();
  }

  void _handleLogout() async {
    await widget.authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            authService: widget.authService,
            apiService: widget.apiService,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF2442),
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF333333),
          unselectedLabelColor: const Color(0xFF999999),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '发现'),
            Tab(text: '附近'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF333333)),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFFFF2442),
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    if (_posts.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF2442),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无推荐内容',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _onRefresh,
              child: const Text(
                '点击刷新',
                style: TextStyle(color: Color(0xFFFF2442)),
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.65,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _posts.length) {
                  return PostCard(post: _posts[index]);
                }
                return null;
              },
              childCount: _posts.length,
            ),
          ),
        ),
        if (_isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF2442),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        if (!_hasMore && _posts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '— 已经到底了 —',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFFFF2442),
      unselectedItemColor: const Color(0xFF999999),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag_outlined),
          activeIcon: Icon(Icons.shopping_bag),
          label: '购物',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline, size: 32),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message_outlined),
          activeIcon: Icon(Icons.message),
          label: '消息',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: '我',
        ),
      ],
      onTap: (index) {
        if (index == 4) {
          // Profile tab - show logout option
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.authService.currentUser != null) ...[
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFF2442),
                        child: Text(
                          widget.authService.currentUser?.nickname
                                  ?.substring(0, 1) ??
                              'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        widget.authService.currentUser?.nickname ?? '用户',
                      ),
                      subtitle: Text(
                        'ID: ${widget.authService.currentUser?.userId ?? ''}',
                      ),
                    ),
                    const Divider(),
                  ],
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFFFF2442)),
                    title: const Text('退出登录'),
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
