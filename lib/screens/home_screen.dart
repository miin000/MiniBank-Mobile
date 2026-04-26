import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../auth/auth_models.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthApi api;
  final AuthStorage storage;

  const HomeScreen({super.key, required this.api, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    widget.storage.getUser().then((u) {
      if (!mounted) return;
      setState(() => _user = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniBank'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.storage.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    api: widget.api,
                    storage: widget.storage,
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          _user == null
              ? 'Logged in'
              : 'Logged in as ${_user!.phone ?? _user!.username ?? ''}',
        ),
      ),
    );
  }
}
