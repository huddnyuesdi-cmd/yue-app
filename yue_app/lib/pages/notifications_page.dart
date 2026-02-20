import 'package:flutter/material.dart';
import '../services/post_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final postService = await PostService.getInstance();
      final notifications = await postService.getNotifications(limit: 50);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final postService = await PostService.getInstance();
      await postService.markAllNotificationsRead();
      await _loadNotifications();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _filterNotifications(String type) {
    if (type == 'all') return _notifications;
    return _notifications.where((n) {
      final nType = n['type'] as String? ?? '';
      switch (type) {
        case 'like':
          return nType == 'like' || nType == 'post_like' || nType == 'comment_like';
        case 'comment':
          return nType == 'comment' || nType == 'reply';
        default:
          return true;
      }
    }).toList();
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final date = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${diff.inHours}小时前';
      if (diff.inDays < 30) return '${diff.inDays}天前';
      return '${date.month}-${date.day}';
    } catch (_) {
      return '';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'like':
      case 'post_like':
      case 'comment_like':
        return Icons.favorite;
      case 'comment':
      case 'reply':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      case 'collect':
        return Icons.star;
      case 'system':
        return Icons.notifications;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'like':
      case 'post_like':
      case 'comment_like':
        return const Color(0xFFFF2442);
      case 'comment':
      case 'reply':
        return const Color(0xFF4A90E2);
      case 'follow':
        return const Color(0xFF7B68EE);
      case 'collect':
        return const Color(0xFFFFB800);
      default:
        return const Color(0xFF999999);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '消息',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              TextButton(
                onPressed: _markAllRead,
                child: const Text(
                  '全部已读',
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
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
              Tab(text: '全部'),
              Tab(text: '点赞'),
              Tab(text: '评论'),
            ],
          ),
        ),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationList('all'),
              _buildNotificationList('like'),
              _buildNotificationList('comment'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationList(String type) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF999999), strokeWidth: 2),
      );
    }

    final filtered = _filterNotifications(type);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'like' ? Icons.favorite_border
                  : type == 'comment' ? Icons.chat_bubble_outline
                  : Icons.notifications_none,
              size: 48,
              color: const Color(0xFFDDDDDD),
            ),
            const SizedBox(height: 12),
            const Text(
              '暂无消息',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF222222),
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
        itemBuilder: (context, index) {
          final notification = filtered[index];
          final notifType = notification['type'] as String?;
          final content = notification['content'] as String? ?? notification['message'] as String? ?? '';
          final createdAt = notification['created_at'] as String?;
          final isRead = notification['is_read'] as bool? ?? notification['read'] as bool? ?? false;
          final senderAvatar = notification['sender_avatar'] as String?;
          final senderName = notification['sender_nickname'] as String? ?? notification['sender_name'] as String? ?? '';
          final avatarCacheSize = (40 * MediaQuery.of(context).devicePixelRatio).toInt();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: isRead ? Colors.white : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getNotificationColor(notifType).withValues(alpha: 0.1),
                    child: senderAvatar != null && senderAvatar.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              senderAvatar,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              cacheWidth: avatarCacheSize,
                              cacheHeight: avatarCacheSize,
                              errorBuilder: (_, __, ___) => Icon(
                                _getNotificationIcon(notifType),
                                size: 20,
                                color: _getNotificationColor(notifType),
                              ),
                            ),
                          )
                        : Icon(
                            _getNotificationIcon(notifType),
                            size: 20,
                            color: _getNotificationColor(notifType),
                          ),
                  ),
                  if (!isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF2442),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                senderName.isNotEmpty ? senderName : _getNotificationTitle(notifType),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'like':
      case 'post_like':
        return '赞了你的笔记';
      case 'comment_like':
        return '赞了你的评论';
      case 'comment':
        return '评论了你的笔记';
      case 'reply':
        return '回复了你的评论';
      case 'follow':
        return '关注了你';
      case 'collect':
        return '收藏了你的笔记';
      case 'system':
        return '系统通知';
      default:
        return '新消息';
    }
  }
}
