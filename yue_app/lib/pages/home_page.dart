import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  UserCenterUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = await AuthService.getInstance();
    final user = authService.getStoredUser();
    if (mounted) {
      setState(() => _user = user);
    }
  }

  Future<void> _handleLogout() async {
    final authService = await AuthService.getInstance();
    await authService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _buildHomePage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_rounded, size: 64, color: Color(0xFFFF6B6B)),
          SizedBox(height: 16),
          Text(
            '欢迎来到 YueM',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '发现美好生活',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_rounded, size: 64, color: Color(0xFFFF6B6B)),
          SizedBox(height: 16),
          Text(
            '发现',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '探索更多精彩内容',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagePage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_rounded, size: 64, color: Color(0xFFFF6B6B)),
          SizedBox(height: 16),
          Text(
            '消息',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '暂无新消息',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Avatar
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFFFF6B6B),
            child: _user?.avatar != null && _user!.avatar!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _user!.avatar!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.person, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _user?.displayName ?? '用户',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${_user?.username ?? ''}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 8),
          Text(
            _user?.email ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
          ),
          const SizedBox(height: 32),
          // Info cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow('用户ID', '${_user?.id ?? '-'}'),
                const Divider(height: 24),
                _buildInfoRow(
                  'VIP等级',
                  _user?.vipLevel != null ? 'VIP ${_user!.vipLevel}' : '普通用户',
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  '邮箱验证',
                  _user?.emailVerified == true ? '已验证' : '未验证',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Logout button
          SizedBox(
            width: double.infinity,
            child: TDButton(
              text: '退出登录',
              size: TDButtonSize.large,
              type: TDButtonType.outline,
              shape: TDButtonShape.round,
              theme: TDButtonTheme.danger,
              isBlock: true,
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
        Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
      ],
    );
  }

  List<Widget> _buildPages() {
    return [
      _buildHomePage(),
      _buildDiscoverPage(),
      _buildMessagePage(),
      _buildProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: TDBottomTabBar(
        TDBottomTabBarBasicType.iconText,
        componentType: TDBottomTabBarComponentType.normal,
        currentIndex: _currentIndex,
        navigationTabs: [
          TDBottomTabBarTabConfig(
            tabText: '首页',
            selectedIcon: Icon(Icons.home_rounded, color: const Color(0xFFFF6B6B)),
            unselectedIcon: Icon(Icons.home_outlined, color: const Color(0xFF999999)),
            onTap: () {
              if (mounted) setState(() => _currentIndex = 0);
            },
          ),
          TDBottomTabBarTabConfig(
            tabText: '发现',
            selectedIcon: Icon(Icons.explore_rounded, color: const Color(0xFFFF6B6B)),
            unselectedIcon: Icon(Icons.explore_outlined, color: const Color(0xFF999999)),
            onTap: () {
              if (mounted) setState(() => _currentIndex = 1);
            },
          ),
          TDBottomTabBarTabConfig(
            tabText: '消息',
            selectedIcon: Icon(Icons.message_rounded, color: const Color(0xFFFF6B6B)),
            unselectedIcon: Icon(Icons.message_outlined, color: const Color(0xFF999999)),
            onTap: () {
              if (mounted) setState(() => _currentIndex = 2);
            },
          ),
          TDBottomTabBarTabConfig(
            tabText: '我的',
            selectedIcon: Icon(Icons.person_rounded, color: const Color(0xFFFF6B6B)),
            unselectedIcon: Icon(Icons.person_outline, color: const Color(0xFF999999)),
            onTap: () {
              if (mounted) setState(() => _currentIndex = 3);
            },
          ),
        ],
      ),
    );
  }
}
