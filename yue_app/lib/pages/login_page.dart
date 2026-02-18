import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'home_page.dart';

/// Login page with 小红书 (Xiaohongshu) style UI.
/// Uses TDesign color scheme and clean design.
class LoginPage extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const LoginPage({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final userId = _userIdController.text.trim();
    final password = _passwordController.text.trim();

    if (userId.isEmpty) {
      setState(() => _errorMessage = '请输入用户ID');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = '请输入密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.login(userId: userId, password: password);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              authService: widget.authService,
              apiService: widget.apiService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          authService: widget.authService,
          apiService: widget.apiService,
        ),
      ),
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
              // Logo and app name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2442),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          'YM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
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
                    const SizedBox(height: 8),
                    const Text(
                      '标记我的生活',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF2442),
                      fontSize: 13,
                    ),
                  ),
                ),

              // User ID field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    hintText: '用户ID',
                    hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Color(0xFFBBBBBB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '密码',
                    hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFFBBBBBB),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFBBBBBB),
                      ),
                      onPressed: () {
                        setState(
                            () => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Login button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2442),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFFFB3BC),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Register link
              Center(
                child: TextButton(
                  onPressed: _goToRegister,
                  child: RichText(
                    text: const TextSpan(
                      text: '还没有账号？',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: '立即注册',
                          style: TextStyle(
                            color: Color(0xFFFF2442),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // OAuth2 login divider
              Row(
                children: [
                  Expanded(
                      child: Divider(color: Colors.grey[300], height: 1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '其他登录方式',
                      style:
                          TextStyle(color: Color(0xFF999999), fontSize: 12),
                    ),
                  ),
                  Expanded(
                      child: Divider(color: Colors.grey[300], height: 1)),
                ],
              ),
              const SizedBox(height: 24),

              // OAuth2 login button
              Center(
                child: InkWell(
                  onTap: _isLoading ? null : _handleOAuth2Login,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.language,
                      color: Color(0xFF666666),
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'YueM账号',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleOAuth2Login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the OAuth2 login URL from community
      final response = await widget.apiService.getOAuth2LoginUrl();
      final data = response.data;

      if (data is Map<String, dynamic>) {
        // The OAuth2 login endpoint may return a redirect URL
        // For mobile, we use the mobile-token exchange flow
        final loginUrl = data['data']?['login_url'] ??
            data['redirect_url'] ??
            data['url'];

        if (loginUrl != null) {
          // In a real app, this would open a WebView or browser
          // For now, show info about the OAuth2 flow
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OAuth2登录: 请在浏览器中完成用户中心登录'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'OAuth2登录暂不可用';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
