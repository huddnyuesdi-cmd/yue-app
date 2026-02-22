import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_service.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

/// System overlay style: transparent status bar, white navigation bar.
const kSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

class YueMApp extends StatelessWidget {
  const YueMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '汐社',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF2442),
          primary: const Color(0xFFFF2442),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF222222),
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: kSystemUiOverlayStyle,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthService>(
      future: AuthService.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFDDDDDD),
                ),
              ),
            ),
          );
        }
        final authService = snapshot.data!;
        if (authService.isLoggedIn()) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
