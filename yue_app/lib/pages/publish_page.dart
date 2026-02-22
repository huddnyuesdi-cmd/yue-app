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
    final hPadding = LayoutConfig.getPublishHorizontalPadding(screenWidth);
    final thumbSize = LayoutConfig.getMediaThumbnailSize(screenWidth);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
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
            padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upload area container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildMediaSection(thumbSize),
                ),
                const SizedBox(height: 10),
                // Title container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: '填写标题，会有更多赞哦~',
                      hintStyle: TextStyle(fontSize: 17, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      counterStyle: TextStyle(color: Color(0xFFBBBBBB)),
                    ),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                    maxLength: 100,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 10),
                // Content container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: '添加正文',
                      hintStyle: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 15, color: Color(0xFF333333), height: 1.6),
                    maxLines: null,
                    minLines: 8,
                  ),
                ),
                // Upload status
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800)),
                          ),
                          SizedBox(width: 6),
                          Text('正在上传媒体文件...', style: TextStyle(fontSize: 12, color: Color(0xFFFF9800))),
                        ],
                      ),
                    ),
                  ),
                // Tags section
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _tagController,
                                  decoration: InputDecoration(
                                    hintText: '# 添加标签',
                                    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: const BorderSide(color: Color(0xFFFF2442)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  onSubmitted: (_) => _addTag(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _addTag,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF2442), Color(0xFFFF5C6A)],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        if (_tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _tags
                                .map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(12),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(double thumbSize) {
    // Build list of media items: images first, then video
    final List<_MediaItem> mediaItems = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      mediaItems.add(_MediaItem(type: _MediaType.image, index: i));
    }

    if (_selectedVideo != null) {
      mediaItems.add(_MediaItem(type: _MediaType.video, index: 0));
    }

    final bool showAddButton = _selectedImages.length < 9 || _selectedVideo == null;

    // Empty state - small compact add button at top-left
    if (mediaItems.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: _showAddMediaSheet,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 28, color: Color(0xFFBBBBBB)),
                SizedBox(height: 2),
                Text('添加', style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
              ],
            ),
          ),
        ),
      );
    }

    // Media items as a compact horizontal row
    final int itemCount = mediaItems.length + (showAddButton ? 1 : 0);

    return SizedBox(
      height: thumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == mediaItems.length) {
            // Compact add button
            return GestureDetector(
              onTap: _showAddMediaSheet,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 24, color: Color(0xFFBBBBBB)),
                    SizedBox(height: 2),
                    Text('添加', style: TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                  ],
                ),
              ),
            );
          }

          final item = mediaItems[index];
          if (item.type == _MediaType.image) {
            return _buildImageItem(item.index, thumbSize);
          } else {
            return _buildVideoItem(thumbSize);
          }
        },
      ),
    );
  }

  Widget _buildImageItem(int index, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImages[index],
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.videocam_rounded, size: 28, color: Colors.white70),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: _removeVideo,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MediaType { image, video }

class _MediaItem {
  final _MediaType type;
  final int index;

  _MediaItem({required this.type, required this.index});
}
