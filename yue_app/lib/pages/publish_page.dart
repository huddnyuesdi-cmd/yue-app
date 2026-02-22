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

class _PublishPageState extends State<PublishPage>
    with SingleTickerProviderStateMixin {
  static const int _maxImageCount = 9;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  bool _isPublishing = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  int _titleLength = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      setState(() => _titleLength = _titleController.text.length);
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    _animController.dispose();
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
    if (_selectedImages.length >= _maxImageCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('最多只能选择9张图片'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final remaining = _maxImageCount - _selectedImages.length;
        final toAdd =
            pickedFiles.take(remaining).map((f) => File(f.path)).toList();
        setState(() {
          _selectedImages.addAll(toAdd);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择图片失败: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _pickVideo() async {
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
        SnackBar(
          content: Text('选择视频失败: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
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

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入标题'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF2442),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
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

      // Auto-determine post type: video present → type 2, otherwise → type 1
      final postType = _selectedVideo != null ? 2 : 1;

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
        type: postType,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
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

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty ||
      _selectedVideo != null;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF333333), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '发布笔记',
          style: TextStyle(
              fontSize: 17,
              color: Color(0xFF222222),
              fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _buildPublishButton(),
          ),
        ],
        bottom: _isUploading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFF2442)),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              LayoutConfig.getMaxFormWidth(constraints.maxWidth);
          final mediaGridColumns =
              LayoutConfig.getMediaGridColumnCount(constraints.maxWidth);
          return FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title input card
                            _buildTitleCard(),
                            const SizedBox(height: 12),
                            // Content input card
                            _buildContentCard(),
                            const SizedBox(height: 12),
                            // Media section card
                            _buildMediaCard(mediaGridColumns),
                            const SizedBox(height: 12),
                            // Tags section card
                            _buildTagsCard(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    // Bottom toolbar
                    _buildBottomToolbar(bottomPadding),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublishButton() {
    final canPublish = _titleController.text.trim().isNotEmpty && !_isPublishing;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canPublish ? _publish : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              gradient: canPublish
                  ? const LinearGradient(
                      colors: [Color(0xFFFF2442), Color(0xFFFF6A78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canPublish ? null : const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(20),
              boxShadow: canPublish
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF2442).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: _isPublishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '发布',
                    style: TextStyle(
                      color: canPublish ? Colors.white : const Color(0xFF999999),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTitleCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '填写标题，会有更多赞哦~',
              hintStyle: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFCCCCCC),
                  fontWeight: FontWeight.w600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              counterText: '',
            ),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222)),
            maxLength: 100,
            maxLines: 2,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '$_titleLength/100',
              style: TextStyle(
                fontSize: 12,
                color: _titleLength > 80
                    ? const Color(0xFFFF2442)
                    : const Color(0xFFCCCCCC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return _buildCard(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _contentController,
        decoration: const InputDecoration(
          hintText: '分享你的想法...',
          hintStyle: TextStyle(fontSize: 15, color: Color(0xFFCCCCCC)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        style: const TextStyle(
            fontSize: 15, color: Color(0xFF333333), height: 1.7),
        maxLines: null,
        minLines: 6,
      ),
    );
  }

  Widget _buildMediaCard(int gridColumns) {
    final totalMedia =
        _selectedImages.length + (_selectedVideo != null ? 1 : 0);
    final canAddImage = _selectedImages.length < _maxImageCount;
    final canAddVideo = _selectedVideo == null;
    final showAddButton = canAddImage || canAddVideo;

    return _buildCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2442), Color(0xFFFF6A78)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '图片 / 视频',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333)),
              ),
              const Spacer(),
              if (totalMedia > 0)
                Text(
                  '${_selectedImages.length}/$_maxImageCount 图片${_selectedVideo != null ? '  ·  1 视频' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF999999)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (totalMedia == 0 && showAddButton)
            _buildEmptyMediaPlaceholder()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: totalMedia + (showAddButton ? 1 : 0),
              itemBuilder: (context, index) {
                // Video item (shown first if present)
                if (_selectedVideo != null && index == 0) {
                  return _buildVideoThumbnail();
                }

                // Offset index for images when video is present
                final imageIndex =
                    _selectedVideo != null ? index - 1 : index;

                // Add button
                if (imageIndex == _selectedImages.length) {
                  return _buildAddMediaButton();
                }

                // Image preview
                return _buildImageThumbnail(imageIndex);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMediaPlaceholder() {
    return GestureDetector(
      onTap: _showMediaPicker,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE8E8E8),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: const Color(0xFFFAFAFC),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF2442).withValues(alpha: 0.1),
                    const Color(0xFFFF6A78).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  size: 26, color: Color(0xFFFF2442)),
            ),
            const SizedBox(height: 10),
            const Text(
              '添加图片或视频',
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              '支持jpg、png、mp4等格式',
              style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline_rounded,
                    size: 36, color: Colors.white70),
                SizedBox(height: 4),
                Text('视频',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: _removeVideo,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _selectedImages[index],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMediaButton() {
    return GestureDetector(
      onTap: _showMediaPicker,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded,
                size: 28,
                color: const Color(0xFFFF2442).withValues(alpha: 0.6)),
            const SizedBox(height: 2),
            const Text('添加',
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard() {
    return _buildCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF2442), Color(0xFFFF6A78)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '标签',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: '输入标签，回车添加',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      isDense: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 12, right: 4),
                        child: Icon(Icons.tag_rounded,
                            size: 18, color: Color(0xFFCCCCCC)),
                      ),
                      prefixIconConstraints:
                          BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2442), Color(0xFFFF6A78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFF2442).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF2442).withValues(alpha: 0.08),
                              const Color(0xFFFF6A78).withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF2442)
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFFF2442),
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _removeTag(tag),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2442)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 12, color: Color(0xFFFF2442)),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildToolbarButton(
            icon: Icons.image_rounded,
            label: '图片',
            onTap: _selectedImages.length < _maxImageCount
                ? _pickImages
                : null,
            badge: _selectedImages.isNotEmpty
                ? '${_selectedImages.length}'
                : null,
          ),
          const SizedBox(width: 20),
          _buildToolbarButton(
            icon: Icons.videocam_rounded,
            label: '视频',
            onTap: _selectedVideo == null ? _pickVideo : null,
            badge: _selectedVideo != null ? '1' : null,
          ),
          const SizedBox(width: 20),
          _buildToolbarButton(
            icon: Icons.tag_rounded,
            label: '标签',
            onTap: () {
              // Scroll to tag section — just focus the tag input
              FocusScope.of(context).requestFocus(FocusNode());
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  FocusScope.of(context).requestFocus(FocusNode());
                }
              });
            },
          ),
          const Spacer(),
          if (_hasContent)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Color(0xFF4CAF50)),
                  SizedBox(width: 4),
                  Text('草稿已保存',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF4CAF50))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    String? badge,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    size: 22,
                    color: isEnabled
                        ? const Color(0xFF555555)
                        : const Color(0xFFBBBBBB)),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2442),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isEnabled
                        ? const Color(0xFF555555)
                        : const Color(0xFFBBBBBB))),
          ],
        ),
      ),
    );
  }

  void _showMediaPicker() {
    final canAddImage = _selectedImages.length < _maxImageCount;
    final canAddVideo = _selectedVideo == null;

    if (canAddImage && canAddVideo) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('添加媒体',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMediaPickerOption(
                          icon: Icons.image_rounded,
                          label: '图片',
                          subtitle:
                              '还可添加 ${_maxImageCount - _selectedImages.length} 张',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImages();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMediaPickerOption(
                          icon: Icons.videocam_rounded,
                          label: '视频',
                          subtitle: 'mp4、mov格式',
                          onTap: () {
                            Navigator.pop(context);
                            _pickVideo();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    } else if (canAddImage) {
      _pickImages();
    } else if (canAddVideo) {
      _pickVideo();
    }
  }

  Widget _buildMediaPickerOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF2442).withValues(alpha: 0.1),
                    const Color(0xFFFF6A78).withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: const Color(0xFFFF2442)),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }
}
