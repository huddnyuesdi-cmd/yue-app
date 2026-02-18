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
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('昵称', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(
              hintText: '请输入昵称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('简介', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '介绍一下自己吧',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
