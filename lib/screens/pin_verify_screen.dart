import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'home_screen.dart';
import 'forgot_pin_screen.dart';

class PinVerifyScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const PinVerifyScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  late String _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final token = await widget.storage.getToken();
      if (!mounted) return;
      setState(() => _token = token ?? '');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Lỗi tải token: $e');
    }
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  String? _validatePin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nhập PIN';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(s)) return 'PIN phải đúng 6 chữ số';
    return null;
  }

  Future<void> _verifyPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.api.verifyPin(_pinCtrl.text.trim(), _token);

      if (!mounted) return;

      // Navigate to home after successful PIN verification
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.lock_outline, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Xác thực mã PIN giao dịch',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập mã PIN của bạn để vào ứng dụng',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Container(
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _pinCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mã PIN (6 chữ số)',
                            prefixIcon: Icon(Icons.pin_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          validator: _validatePin,
                          enabled: !_loading,
                          autofocus: true,
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
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        if (_error != null) const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading ? null : _verifyPin,
                          child: Text(_loading ? 'Đang xác thực...' : 'Xác thực'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ForgotPinScreen(
                                        baseUrl: widget.baseUrl,
                                        api: widget.api,
                                        storage: widget.storage,
                                        identity: widget.identity,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Quên mã PIN?'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
