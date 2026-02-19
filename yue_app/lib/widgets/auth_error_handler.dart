import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../services/auth_service.dart';

mixin AuthErrorHandler<T extends StatefulWidget> on State<T> {
  bool isAuthError(String errorMessage) {
    return errorMessage == '请先登录' || errorMessage.contains('(401)');
  }

  Future<void> redirectToLogin() async {
    final authService = await AuthService.getInstance();
    await authService.logout();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }
}
