import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth/auth_api.dart';
import 'auth/auth_storage.dart';
import 'security/device_identity.dart';
import 'screens/login_screen.dart';
import 'screens/pin_unlock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  const apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  final envBaseUrl = dotenv.env['API_BASE_URL'];
  final defaultBaseUrl = kIsWeb
      ? 'http://localhost:8081'
      : (Platform.isAndroid ? 'http://10.0.2.2:8081' : 'http://localhost:8081');
  final normalizedEnvBaseUrl = !kIsWeb && Platform.isAndroid && envBaseUrl != null
      ? envBaseUrl
          .replaceFirst('http://localhost:', 'http://10.0.2.2:')
          .replaceFirst('http://127.0.0.1:', 'http://10.0.2.2:')
      : envBaseUrl;
  final apiBaseUrl = apiBaseUrlOverride.isNotEmpty
      ? apiBaseUrlOverride
      : (normalizedEnvBaseUrl != null && normalizedEnvBaseUrl.isNotEmpty ? normalizedEnvBaseUrl : defaultBaseUrl);
  // NOTE:
  // - Android emulator: use http://10.0.2.2:8081
  // - iOS simulator: http://localhost:8081
  // - Real device: use your machine LAN IP, e.g. http://192.168.1.10:8081

  final api = AuthApi(baseUrl: apiBaseUrl);
  final storage = AuthStorage();
  final identity = DeviceIdentity();
  runApp(MyApp(baseUrl: apiBaseUrl, api: api, storage: storage, identity: identity));
}

class MyApp extends StatelessWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const MyApp({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniBank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: FutureBuilder<String?>(
        future: storage.getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final token = snapshot.data;
          if (token != null && token.isNotEmpty) {
            return PinUnlockScreen(baseUrl: baseUrl, api: api, storage: storage, identity: identity);
          }
          return LoginScreen(baseUrl: baseUrl, api: api, storage: storage, identity: identity);
        },
      ),
    );
  }
}
