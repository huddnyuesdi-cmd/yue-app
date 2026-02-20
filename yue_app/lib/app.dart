import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/splash_page.dart';

/// System overlay style: fully transparent status & navigation bars (edge-to-edge).
const kSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
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
      home: const SplashPage(),
    );
  }
}
