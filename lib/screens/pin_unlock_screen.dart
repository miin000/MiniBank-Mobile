import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const PinUnlockScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profileApi = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await profileApi.verifyPin(pin: _pinCtrl.text.trim());

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            baseUrl: widget.baseUrl,
            api: widget.api,
            storage: widget.storage,
            identity: widget.identity,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logoutAndRelogin() async {
    await widget.storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          baseUrl: widget.baseUrl,
          api: widget.api,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2B63), Color(0xFF2A64D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 20),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Nhập PIN để mở ứng dụng',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Phiên đã được lưu, nhưng bạn vẫn cần nhập mã PIN mỗi lần mở lại ứng dụng.',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mã PIN',
                            prefixIcon: Icon(Icons.pin_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length != 6) return 'Nhập PIN 6 số';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                            ),
                          ),
                        if (_error != null) const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading ? null : _unlock,
                          child: Text(_loading ? 'Đang kiểm tra...' : 'Mở khóa'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _loading ? null : _logoutAndRelogin,
                          child: const Text('Đăng nhập lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}