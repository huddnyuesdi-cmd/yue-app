import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      TDToast.showWarning('请输入邮箱', context: context);
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      TDToast.showWarning('请输入有效的邮箱地址', context: context);
      return;
    }
    if (username.isEmpty) {
      TDToast.showWarning('请输入用户名', context: context);
      return;
    }
    if (displayName.isEmpty) {
      TDToast.showWarning('请输入显示名称', context: context);
      return;
    }
    if (password.isEmpty) {
      TDToast.showWarning('请输入密码', context: context);
      return;
    }
    if (password.length < 6) {
      TDToast.showWarning('密码至少需要6个字符', context: context);
      return;
    }
    if (password != confirmPassword) {
      TDToast.showWarning('两次输入的密码不一致', context: context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = await AuthService.getInstance();

      // Check if captcha is required
      String? captchaId;
      final captchaStatus = await authService.getCaptchaStatus();
      if (captchaStatus.enabled) {
        if (!mounted) return;
        captchaId = await SlideCaptchaDialog.show(context);
        if (captchaId == null) {
          // User cancelled captcha
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

      TDToast.showSuccess('注册成功', context: context);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      TDToast.showFail(message, context: context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('注册'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  '创建 YueM 账号',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TDInput(
                controller: _emailController,
                leftLabel: '邮箱',
                hintText: '请输入邮箱地址',
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: true,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 12),
              TDInput(
                controller: _usernameController,
                leftLabel: '用户名',
                hintText: '请输入用户名',
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: true,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 12),
              TDInput(
                controller: _displayNameController,
                leftLabel: '昵称',
                hintText: '请输入显示名称',
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: true,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 12),
              TDInput(
                controller: _passwordController,
                leftLabel: '密码',
                hintText: '请输入密码（至少6位）',
                obscureText: true,
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: false,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 12),
              TDInput(
                controller: _confirmPasswordController,
                leftLabel: '确认密码',
                hintText: '请再次输入密码',
                obscureText: true,
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: false,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 32),
              TDButton(
                text: '注册',
                size: TDButtonSize.large,
                type: TDButtonType.fill,
                shape: TDButtonShape.round,
                theme: TDButtonTheme.primary,
                isBlock: true,
                disabled: _isLoading,
                onTap: _isLoading ? null : _handleRegister,
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '已有账号？返回登录',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
