import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../config/layout_config.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'post_card.dart';

class FollowingFeed extends StatefulWidget {
  const FollowingFeed({super.key});

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> with AutomaticKeepAliveClientMixin {
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final postService = await PostService.getInstance();
      final response = await postService.getFollowingPosts(page: 1, limit: 20);
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(response.posts);
          _page = 2;
          _hasMore = response.pagination != null &&
              response.pagination!.page < response.pagination!.pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final postService = await PostService.getInstance();
      final response = await postService.getFollowingPosts(page: _page, limit: 20);
      if (mounted) {
        setState(() {
          _posts.addAll(response.posts);
          _page++;
          _hasMore = response.pagination != null &&
              response.pagination!.page < response.pagination!.pages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_error != null && _posts.isEmpty) {
      return _buildErrorView();
    }

    if (_posts.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2),
      );
    }

    if (_posts.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: const Color(0xFF222222),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = LayoutConfig.getGridColumnCount(constraints.maxWidth);
          return MasonryGridView.count(
            controller: _scrollController,
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.all(8),
            itemCount: _posts.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _posts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF999999)),
                    ),
                  ),
                );
              }
              return PostCard(post: _posts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            Text(
              _error ?? '加载失败',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadPosts,
              child: const Text('点击重试', style: TextStyle(color: Color(0xFFFF2442))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 48, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 16),
          const Text(
            '还没有关注任何人',
            style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 8),
          const Text(
            '关注感兴趣的用户，这里会显示他们的动态',
            style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadPosts,
            child: const Text('刷新试试', style: TextStyle(color: Color(0xFFFF2442))),
          ),
        ],
      ),
    );
  }
}
