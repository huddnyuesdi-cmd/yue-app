import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../config/layout_config.dart';
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
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(21),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索笔记、用户、标签',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Icon(Icons.search_rounded, color: Color(0xFFBBBBBB), size: 22),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF999999), size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Row(
                children: [
                  const Text(
                    '🔥 热门标签',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _hotTags.map((tag) {
                  final tagName = tag['name'] as String? ?? '';
                  final postCount = tag['post_count'] as int? ?? 0;
                  return GestureDetector(
                    onTap: () => _search(tag: tagName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$tagName',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF333333),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (postCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$postCount',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.explore_outlined, size: 48, color: const Color(0xFFDDDDDD).withValues(alpha: 0.7)),
                  const SizedBox(height: 12),
                  const Text(
                    '搜索发现更多精彩内容',
                    style: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && _searchResults.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFDDDDDD)),
            SizedBox(height: 12),
            Text(
              '没有找到相关内容',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = LayoutConfig.getGridColumnCount(constraints.maxWidth);
        return MasonryGridView.count(
          controller: _scrollController,
          crossAxisCount: crossAxisCount,
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF999999)),
                  ),
                ),
              );
            }
            return PostCard(post: _searchResults[index]);
          },
        );
      },
    );
  }
}
