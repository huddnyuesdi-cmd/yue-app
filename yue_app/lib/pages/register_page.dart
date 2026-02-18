import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

/// Registration page with 小红书 (Xiaohongshu) style UI.
class RegisterPage extends StatefulWidget {
  final AuthService authService;
  final ApiService apiService;

  const RegisterPage({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _userIdController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  // Captcha state
  String? _captchaId;
  String? _captchaImage;
  final _captchaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    try {
      final response = await widget.apiService.getCaptcha();
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['code'] == 200) {
          final captchaData = data['data'];
          if (captchaData is Map<String, dynamic>) {
            setState(() {
              _captchaId = captchaData['captcha_id']?.toString() ??
                  captchaData['id']?.toString();
              _captchaImage = captchaData['captcha_image']?.toString() ??
                  captchaData['image']?.toString();
            });
          }
        }
      }
    } catch (_) {
      // Captcha may not be required
    }
  }

  Future<void> _handleRegister() async {
    final userId = _userIdController.text.trim();
    final nickname = _nicknameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (userId.isEmpty) {
      setState(() => _errorMessage = '请输入用户ID');
      return;
    }
    if (userId.length < 3) {
      setState(() => _errorMessage = '用户ID至少3个字符');
      return;
    }
    if (nickname.isEmpty) {
      setState(() => _errorMessage = '请输入昵称');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = '请输入密码');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = '密码至少6个字符');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = '两次密码输入不一致');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.register(
        userId: userId,
        nickname: nickname,
        password: password,
        captchaId: _captchaId,
        captchaText: _captchaController.text.trim().isNotEmpty
            ? _captchaController.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomePage(
              authService: widget.authService,
              apiService: widget.apiService,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        _loadCaptcha(); // Reload captcha on error
      }
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF333333)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '注册',
          style: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Welcome text
              const Text(
                '创建账号',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '加入YueM，记录美好生活',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 32),

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
              _buildInputField(
                controller: _userIdController,
                hintText: '用户ID（登录用）',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              // Nickname field
              _buildInputField(
                controller: _nicknameController,
                hintText: '昵称',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),

              // Password field
              _buildPasswordField(
                controller: _passwordController,
                hintText: '密码（至少6位）',
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),

              // Confirm password field
              _buildPasswordField(
                controller: _confirmPasswordController,
                hintText: '确认密码',
                obscure: _obscureConfirmPassword,
                onToggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              const SizedBox(height: 16),

              // Captcha field (if captcha is available)
              if (_captchaId != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _captchaController,
                        hintText: '验证码',
                        icon: Icons.security_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _loadCaptcha,
                      child: Container(
                        width: 120,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _captchaImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _captchaImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text('点击刷新',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Text('点击获取',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF999999))),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),

              // Register button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
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
                          '注册',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Login link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: RichText(
                    text: const TextSpan(
                      text: '已有账号？',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: '去登录',
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
              const SizedBox(height: 32),

              // Terms text
              Center(
                child: Text(
                  '注册即表示同意《用户协议》和《隐私政策》',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(icon, color: const Color(0xFFBBBBBB)),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon:
              const Icon(Icons.lock_outline, color: Color(0xFFBBBBBB)),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFFBBBBBB),
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
