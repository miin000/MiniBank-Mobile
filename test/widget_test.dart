// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:minibank/main.dart';
import 'package:minibank/auth/auth_api.dart';
import 'package:minibank/auth/auth_storage.dart';
import 'package:minibank/security/device_identity.dart';

void main() {
  testWidgets('Shows login screen when signed out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final api = AuthApi(baseUrl: 'http://localhost:8080');
    final storage = AuthStorage();
    final identity = DeviceIdentity();

    await tester.pumpWidget(
      MyApp(baseUrl: 'http://localhost:8080', api: api, storage: storage, identity: identity),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng trở lại'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
  });
}
