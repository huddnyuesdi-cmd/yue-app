import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/layout_config.dart';
import '../services/post_service.dart';

class PublishPage extends StatefulWidget {
  const PublishPage({super.key});

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  bool _isPublishing = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  int get _postType => _selectedVideo != null ? 2 : 1;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多只能选择9张图片')),
      );
      return;
    }

    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final remaining = 9 - _selectedImages.length;
        final toAdd = pickedFiles.take(remaining).map((f) => File(f.path)).toList();
        setState(() {
          _selectedImages.addAll(toAdd);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickVideo() async {
    if (_selectedVideo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多只能选择1个视频')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (pickedFile != null) {
        setState(() {
          _selectedVideo = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: ${e.toString()}')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
    });
  }

  void _showAddMediaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (_selectedImages.length < 9)
                  ListTile(
                    leading: const Icon(Icons.image_rounded, color: Color(0xFFFF2442)),
                    title: const Text('添加图片', style: TextStyle(fontSize: 15)),
                    subtitle: Text('还可添加${9 - _selectedImages.length}张',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImages();
                    },
                  ),
                if (_selectedVideo == null)
                  ListTile(
                    leading: const Icon(Icons.videocam_rounded, color: Color(0xFFFF2442)),
                    title: const Text('添加视频', style: TextStyle(fontSize: 15)),
                    subtitle: const Text('支持mp4、mov等格式，最长10分钟',
                        style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo();
                    },
                  ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF7F7F8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('取消',
                          style: TextStyle(fontSize: 15, color: Color(0xFF666666))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
      _isUploading = _selectedImages.isNotEmpty || _selectedVideo != null;
    });

    try {
      final postService = await PostService.getInstance();
      List<String>? imageUrls;
      String? videoUrl;

      // Upload images
      if (_selectedImages.isNotEmpty) {
        imageUrls = [];
        for (final imageFile in _selectedImages) {
          final url = await postService.uploadImage(imageFile.path);
          imageUrls.add(url);
        }
      }

      // Upload video
      if (_selectedVideo != null) {
        videoUrl = await postService.uploadVideo(_selectedVideo!.path);
      }

      if (mounted) {
        setState(() => _isUploading = false);
      }

      await postService.createPost(
        title: title,
        content: content,
        tags: _tags,
        imageUrls: imageUrls,
        video: videoUrl,
        type: _postType,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final publishMaxWidth = LayoutConfig.getPublishMaxWidth(screenWidth);
    final gridColumns = LayoutConfig.getMediaGridColumns(screenWidth);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '发布笔记',
          style: TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isPublishing ? null : _publish,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF2442),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isPublishing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('发布', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: publishMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unified media section
                _buildMediaSection(gridColumns),
                const SizedBox(height: 16),
                // Title input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: '填写标题，会有更多赞哦~',
                      hintStyle: TextStyle(fontSize: 17, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      counterStyle: TextStyle(color: Color(0xFFBBBBBB)),
                    ),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                    maxLength: 100,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                // Content input
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: '添加正文',
                      hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: const TextStyle(fontSize: 15, color: Color(0xFF333333), height: 1.6),
                    maxLines: null,
                    minLines: 8,
                  ),
                ),
                const SizedBox(height: 20),
                // Upload status
                if (_isUploading)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800)),
                        ),
                        SizedBox(width: 8),
                        Text('正在上传媒体文件...', style: TextStyle(fontSize: 13, color: Color(0xFFFF9800))),
                      ],
                    ),
                  ),
                // Tags section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '添加标签',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: TextField(
                                controller: _tagController,
                                decoration: const InputDecoration(
                                  hintText: '输入标签',
                                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 13),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _addTag,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF2442), Color(0xFFFF5C6A)],
                                ),
                                borderRadius: BorderRadius.circular(19),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _tags
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('#$tag', style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => _removeTag(tag),
                                          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF999999)),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(int gridColumns) {
    // Build list of media items: images first, then video
    final List<_MediaItem> mediaItems = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      mediaItems.add(_MediaItem(type: _MediaType.image, index: i));
    }

    if (_selectedVideo != null) {
      mediaItems.add(_MediaItem(type: _MediaType.video, index: 0));
    }

    final bool showAddButton = _selectedImages.length < 9 || _selectedVideo == null;
    final int itemCount = mediaItems.length + (showAddButton ? 1 : 0);

    // Empty state - show large add area
    if (mediaItems.isEmpty) {
      return GestureDetector(
        onTap: _showAddMediaSheet,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Color(0xFFBBBBBB)),
              SizedBox(height: 10),
              Text('添加图片或视频', style: TextStyle(fontSize: 15, color: Color(0xFF999999))),
              SizedBox(height: 4),
              Text('图片最多9张，视频最多1个', style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridColumns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == mediaItems.length) {
              // Add button
              return GestureDetector(
                onTap: _showAddMediaSheet,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 32, color: Color(0xFFBBBBBB)),
                      SizedBox(height: 4),
                      Text('添加', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                    ],
                  ),
                ),
              );
            }

            final item = mediaItems[index];
            if (item.type == _MediaType.image) {
              return _buildImageItem(item.index);
            } else {
              return _buildVideoItem();
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '图片 ${_selectedImages.length}/9'
            '${_selectedVideo != null ? '  视频 1/1' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ),
      ],
    );
  }

  Widget _buildImageItem(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            _selectedImages[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoItem() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_rounded, size: 32, color: Colors.white70),
                SizedBox(height: 4),
                Text('视频', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _removeVideo,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

enum _MediaType { image, video }

class _MediaItem {
  final _MediaType type;
  final int index;

  _MediaItem({required this.type, required this.index});
}
