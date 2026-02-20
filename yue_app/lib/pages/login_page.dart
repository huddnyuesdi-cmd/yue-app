import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../config/layout_config.dart';
import '../services/auth_service.dart';
import '../widgets/slide_captcha_widget.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      _showSnackBar('请输入用户名或邮箱');
      return;
    }
    if (password.isEmpty) {
      _showSnackBar('请输入密码');
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

      await authService.login(username, password, captchaId: captchaId);

      if (!mounted) return;

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

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF2442) : const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LayoutConfig.maxFormWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                // Logo
                Center(child: _buildLogo()),
                const SizedBox(height: 48),
                // Welcome text
                const Text(
                  '欢迎回来',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '登录你的账号，发现精彩内容',
                  style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                ),
                const SizedBox(height: 36),
                // Username field
                _buildInputField(
                  controller: _usernameController,
                  hintText: '用户名 / 邮箱',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                // Password field
                _buildInputField(
                  controller: _passwordController,
                  hintText: '密码',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFFCCCCCC),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                const SizedBox(height: 36),
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2442),
                      disabledBackgroundColor: const Color(0xFFFFB4B4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
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
                            '登 录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '还没有账号？',
                        style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                      ),
                      GestureDetector(
                        onTap: _goToRegister,
                        child: const Text(
                          '立即注册',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFFF2442),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFF2442),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Text(
              '汐',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '汐社',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFFCCCCCC), size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
