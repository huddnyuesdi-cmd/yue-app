import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _hotTags = [];
  List<Post> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _currentKeyword;
  String? _currentTag;

  @override
  void initState() {
    super.initState();
    _loadHotTags();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadHotTags() async {
    try {
      final postService = await PostService.getInstance();
      final tags = await postService.getHotTags(limit: 20);
      if (mounted) {
        setState(() => _hotTags = tags);
      }
    } catch (_) {}
  }

  Future<void> _search({String? keyword, String? tag}) async {
    if (_isLoading) return;
    setState(() {
      _isSearching = true;
      _isLoading = true;
      _page = 1;
      _currentKeyword = keyword;
      _currentTag = tag;
      _searchResults.clear();
    });

    try {
      final postService = await PostService.getInstance();
      final response = await postService.searchPosts(
        keyword: keyword,
        tag: tag,
        page: 1,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _searchResults = response.posts;
          _page = 2;
          _hasMore = response.pagination != null &&
              response.pagination!.page < response.pagination!.pages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || !_isSearching) return;
    setState(() => _isLoading = true);

    try {
      final postService = await PostService.getInstance();
      final response = await postService.searchPosts(
        keyword: _currentKeyword,
        tag: _currentTag,
        page: _page,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _searchResults.addAll(response.posts);
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

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchResults.clear();
      _searchController.clear();
      _currentKeyword = null;
      _currentTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索笔记、用户、标签',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFBBBBBB), size: 20),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF999999), size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _search(keyword: value.trim());
                }
              },
            ),
          ),
        ),
        // Content
        Expanded(
          child: _isSearching ? _buildSearchResults() : _buildDiscoverContent(),
        ),
      ],
    );
  }

  Widget _buildDiscoverContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hot tags
          if (_hotTags.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                '热门标签',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _hotTags.map((tag) {
                  final tagName = tag['name'] as String? ?? '';
                  final postCount = tag['post_count'] as int? ?? 0;
                  return GestureDetector(
                    onTap: () => _search(tag: tagName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$tagName',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (postCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$postCount',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFFF9999)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // Explore tips
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Column(
              children: [
                Icon(Icons.explore_outlined, size: 48, color: Color(0xFFDDDDDD)),
                SizedBox(height: 12),
                Text(
                  '搜索发现更多精彩内容',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && _searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Color(0xFFDDDDDD)),
            SizedBox(height: 12),
            Text(
              '没有找到相关内容',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      controller: _scrollController,
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: const EdgeInsets.all(8),
      itemCount: _searchResults.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)),
              ),
            ),
          );
        }
        return PostCard(post: _searchResults[index]);
      },
    );
  }
}
