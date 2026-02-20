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
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Tab header - clean centered tabs like Xiaohongshu
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF222222),
              unselectedLabelColor: const Color(0xFFBBBBBB),
              labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal),
              indicatorColor: const Color(0xFFFF2442),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: const [
                Tab(text: '关注'),
                Tab(text: '发现'),
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
                WaterfallFeed(), // Discover feed reuses waterfall
                WaterfallFeed(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
