import 'package:flutter/material.dart';

import 'auth/auth_api.dart';
import 'auth/auth_storage.dart';
import 'security/device_identity.dart';
import 'screens/login_screen.dart';
import 'screens/pin_unlock_screen.dart';

void main() {
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );
  // NOTE:
  // - Android emulator: use http://10.0.2.2:8080
  // - iOS simulator: http://localhost:8080
  // - Real device: use your machine LAN IP, e.g. http://192.168.1.10:8080

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
