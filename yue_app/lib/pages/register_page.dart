import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/slide_captcha_widget.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      _showSnackBar('请输入邮箱');
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _showSnackBar('请输入有效的邮箱地址');
      return;
    }
    if (username.isEmpty) {
      _showSnackBar('请输入用户名');
      return;
    }
    if (displayName.isEmpty) {
      _showSnackBar('请输入昵称');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('请输入密码');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('密码至少需要6个字符');
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('两次输入的密码不一致');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = await AuthService.getInstance();

      String? captchaId;
      final captchaStatus = await authService.getCaptchaStatus();
      if (captchaStatus.enabled) {
        if (!mounted) return;
        captchaId = await SlideCaptchaDialog.show(context);
        if (captchaId == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      await authService.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
        captchaId: captchaId,
      );

      if (!mounted) return;

      _showSnackBar('注册成功', isError: false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF6B6B),
              Color(0xFFFF8E8E),
              Color(0xFFFFB4B4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Title
              const Text(
                '创建账号',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '加入汐社，分享你的校园生活',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 24),
              // Form card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller: _emailController,
                          hintText: '邮箱地址',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _usernameController,
                          hintText: '用户名',
                          prefixIcon: Icons.alternate_email_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _displayNameController,
                          hintText: '昵称',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _passwordController,
                          hintText: '密码（至少6位）',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFFBBBBBB),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _confirmPasswordController,
                          hintText: '确认密码',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFFBBBBBB),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirm = !_obscureConfirm);
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Register button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B6B),
                              disabledBackgroundColor: const Color(0xFFFFB4B4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '注 册',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Login link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '已有账号？',
                                style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  '返回登录',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFFF6B6B),
                                    fontWeight: FontWeight.w600,
                                  ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFFBBBBBB), size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
