import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app.dart';
import '../services/auth_service.dart';
import 'home_page.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _requestPermissions();
    _checkAuth();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
      ].request();
    }
  }

  Future<void> _checkAuth() async {
    // Brief delay for splash display
    await Future.delayed(const Duration(milliseconds: 800));

    final authService = await AuthService.getInstance();
    final loggedIn = authService.isLoggedIn();

    if (!mounted) return;

    final destination = loggedIn ? const HomePage() : const LoginPage();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF2442),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text(
                  '汐',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '汐社',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFDDDDDD),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
