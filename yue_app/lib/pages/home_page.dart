import 'package:flutter/material.dart';
import '../config/layout_config.dart';
import 'discover_page.dart';
import 'home_feed_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'publish_page.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  int _refreshKey = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _buildPages();
    _checkForUpdate();
  }

  void _buildPages() {
    _pages = [
      HomeFeedPage(key: ValueKey('home_$_refreshKey')),
      const DiscoverPage(),
      const SizedBox(), // Placeholder for center publish button
      NotificationsPage(key: ValueKey('notif_$_refreshKey')),
      ProfilePage(key: ValueKey('profile_$_refreshKey')),
    ];
  }

  Future<void> _checkForUpdate() async {
    // Brief delay to ensure the home page is fully rendered
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final updateInfo = await UpdateService.checkUpdate();
    if (!mounted) return;

    if (updateInfo != null && updateInfo.hasUpdate) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = LayoutConfig.scaleFactor(screenWidth);
    final navHeight = (52 * scale).roundToDouble();
    final iconSize = (24 * scale).clampDouble(20, 28);
    final fontSize = (10 * scale).clampDouble(9, 12);
    final publishWidth = (44 * scale).roundToDouble();
    final publishHeight = (32 * scale).roundToDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: navHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(0, Icons.home_rounded, Icons.home_outlined, '首页', iconSize: iconSize, fontSize: fontSize),
                _buildTabItem(1, Icons.explore_rounded, Icons.explore_outlined, '发现', iconSize: iconSize, fontSize: fontSize),
                _buildPublishButton(width: publishWidth, height: publishHeight, iconSize: iconSize),
                _buildTabItem(3, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, '消息', iconSize: iconSize, fontSize: fontSize),
                _buildTabItem(4, Icons.person_rounded, Icons.person_outline_rounded, '我的', iconSize: iconSize, fontSize: fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData activeIcon, IconData icon, String label, {required double iconSize, required double fontSize}) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (mounted) setState(() => _currentIndex = index);
      },
      child: SizedBox(
        width: iconSize * 2.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: iconSize,
              color: isActive ? const Color(0xFF222222) : const Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: isActive ? const Color(0xFF222222) : const Color(0xFFBBBBBB),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishButton({required double width, required double height, required double iconSize}) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PublishPage()),
        );
        if (result == true && mounted) {
          // Force rebuild all pages to show fresh data
          setState(() {
            _refreshKey++;
            _buildPages();
            _currentIndex = 0;
          });
        }
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFFF2442),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.add_rounded, color: Colors.white, size: iconSize),
      ),
    );
  }
}
