import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const PinSetupScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  String? _validatePin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nhập PIN';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(s)) return 'PIN phải đúng 6 chữ số';
    return null;
  }

  Future<void> _setupPin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinCtrl.text.trim() != _confirmPinCtrl.text.trim()) {
      setState(() => _error = 'PIN xác nhận không khớp');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await api.setOrChangePin(
        oldPin: null,
        newPin: _pinCtrl.text.trim(),
      );

      if (!mounted) return;
      
      // Navigate to home after successful PIN setup
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
                  'Thiết lập mã PIN giao dịch',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mã PIN sẽ được sử dụng để xác thực mọi giao dịch của bạn',
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
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPinCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Xác nhận mã PIN',
                            prefixIcon: Icon(Icons.pin_rounded),
                          ),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          validator: _validatePin,
                          enabled: !_loading,
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
                          onPressed: _loading ? null : _setupPin,
                          child: Text(_loading ? 'Đang thiết lập...' : 'Thiết lập PIN'),
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
