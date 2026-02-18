import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      TDToast.showWarning('请输入用户名或邮箱', context: context);
      return;
    }
    if (password.isEmpty) {
      TDToast.showWarning('请输入密码', context: context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = await AuthService.getInstance();
      await authService.login(username, password);

      if (!mounted) return;

      TDToast.showSuccess('登录成功', context: context);

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

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              // Logo & App Name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          '悦',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'YueM',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '悦M · 发现美好生活',
                      style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Username input
              TDInput(
                controller: _usernameController,
                leftLabel: '账号',
                hintText: '请输入用户名或邮箱',
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: true,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 16),
              // Password input
              TDInput(
                controller: _passwordController,
                leftLabel: '密码',
                hintText: '请输入密码',
                obscureText: true,
                backgroundColor: const Color(0xFFF5F5F5),
                needClear: false,
                cardStyle: TDCardStyle.topText,
              ),
              const SizedBox(height: 32),
              // Login button
              TDButton(
                text: '登录',
                size: TDButtonSize.large,
                type: TDButtonType.fill,
                shape: TDButtonShape.round,
                theme: TDButtonTheme.primary,
                isBlock: true,
                disabled: _isLoading,
                onTap: _isLoading ? null : _handleLogin,
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
              // Register link
              Center(
                child: TextButton(
                  onPressed: _goToRegister,
                  child: const Text(
                    '还没有账号？立即注册',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
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
}
