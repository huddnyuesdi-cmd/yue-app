import 'package:flutter/material.dart';
import '../services/post_service.dart';

class EditProfilePage extends StatefulWidget {
  final int userId;
  final String? nickname;
  final String? avatar;
  final String? bio;

  const EditProfilePage({
    super.key,
    required this.userId,
    this.nickname,
    this.avatar,
    this.bio,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.nickname ?? '');
    _bioController = TextEditingController(text: widget.bio ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final postService = await PostService.getInstance();
      final updates = <String, dynamic>{};

      final newNickname = _nicknameController.text.trim();
      if (newNickname.isNotEmpty && newNickname != widget.nickname) {
        updates['nickname'] = newNickname;
      }

      final newBio = _bioController.text.trim();
      if (newBio != (widget.bio ?? '')) {
        updates['bio'] = newBio;
      }

      if (updates.isEmpty) {
        Navigator.of(context).pop(false);
        return;
      }

      await postService.updateUserProfile(widget.userId, updates);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '编辑资料',
          style: TextStyle(fontSize: 16, color: Color(0xFF333333), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('保存', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('昵称', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _nicknameController,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                    decoration: const InputDecoration(
                      hintText: '请输入昵称',
                      hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('简介', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                    decoration: const InputDecoration(
                      hintText: '介绍一下自己吧',
                      hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
