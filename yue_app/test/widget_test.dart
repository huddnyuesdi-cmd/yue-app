// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:yue_app/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const YueMApp());
    // Verify splash page renders with app name
    expect(find.text('YueM'), findsOneWidget);
  });
}
