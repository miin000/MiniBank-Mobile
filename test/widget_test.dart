// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minibank/main.dart';
import 'package:minibank/auth/auth_api.dart';
import 'package:minibank/auth/auth_storage.dart';

void main() {
  testWidgets('Shows login screen when signed out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final api = AuthApi(baseUrl: 'http://localhost:8080');
    final storage = AuthStorage();

    await tester.pumpWidget(MyApp(api: api, storage: storage));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký tài khoản'), findsOneWidget);
  });
}
