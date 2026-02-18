import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'discover_page.dart';
import 'home_feed_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'publish_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  Widget _buildHomePage() {
    return const HomeFeedPage();
  }

  Widget _buildDiscoverPage() {
    return const DiscoverPage();
  }

  Widget _buildMessagePage() {
    return const NotificationsPage();
  }

  Widget _buildProfilePage() {
    return const ProfilePage();
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(child: pages[_currentIndex]),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PublishPage()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
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
