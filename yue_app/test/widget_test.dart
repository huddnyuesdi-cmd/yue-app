// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import 'package:yue_app/pages/login_page.dart';

void main() {
  testWidgets('Login page renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      TDTheme(
        data: TDTheme.defaultData(),
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // Verify login page renders with key elements
    expect(find.text('YueM'), findsOneWidget);
    expect(find.text('悦'), findsOneWidget);
    expect(find.text('悦M · 发现美好生活'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('还没有账号？立即注册'), findsOneWidget);
  });
}
