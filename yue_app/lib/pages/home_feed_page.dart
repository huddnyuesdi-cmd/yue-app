import 'package:flutter/material.dart';
import '../widgets/waterfall_feed.dart';
import '../widgets/following_feed.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab header
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF6B6B),
            unselectedLabelColor: const Color(0xFF999999),
            labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            indicatorColor: const Color(0xFFFF6B6B),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            indicatorPadding: const EdgeInsets.only(bottom: 2),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '关注'),
              Tab(text: '推荐'),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              FollowingFeed(),
              WaterfallFeed(),
            ],
          ),
        ),
      ],
    );
  }
}
