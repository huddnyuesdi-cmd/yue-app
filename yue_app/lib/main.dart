import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const YueApp());
}

/// YueM App - 小红书风格图文社区
///
/// Architecture:
/// - ApiService: HTTP client for community & user center APIs
/// - AuthService: Handles login, register, OAuth2, token management
/// - Pages: LoginPage, RegisterPage, HomePage
///
/// Auth Flow:
/// 1. On app start, check for stored JWT token
/// 2. If token exists, validate and auto-login
/// 3. If no token, show login page
/// 4. Login supports: native login (user_id + password) and OAuth2 via user center
/// 5. After login, community JWT is stored and used for all subsequent API calls
///
/// OAuth2 Flow (via user center):
/// 1. Community redirects to user center login (user.yuelk.com)
/// 2. User authenticates at user center
/// 3. User center issues a user_token
/// 4. App exchanges user_token at /api/auth/oauth2/mobile-token
/// 5. Community validates and returns community access_token + refresh_token
class YueApp extends StatelessWidget {
  const YueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YueM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF2442),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF2442),
          primary: const Color(0xFFFF2442),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF333333)),
          titleTextStyle: TextStyle(
            color: Color(0xFF333333),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash screen that checks auth state and navigates accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final ApiService _apiService;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService(_apiService);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Small delay for splash screen display
    await Future.delayed(const Duration(milliseconds: 500));

    bool isLoggedIn = false;
    try {
      isLoggedIn = await _authService.initAuth();
    } catch (_) {
      // Auth initialization failed - go to login
    }

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(
            authService: _authService,
            apiService: _apiService,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            authService: _authService,
            apiService: _apiService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2442),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Center(
                child: Text(
                  'YM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'YueM',
              style: TextStyle(
                fontSize: 32,
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
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(0xFFFF2442),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
