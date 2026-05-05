import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'home_screen.dart';

enum _PinResetStep { otp, newPin }

class ForgotPinScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const ForgotPinScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _devOtpHint;
  _PinResetStep _step = _PinResetStep.otp;
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
      _sendOtp();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Lỗi tải token: $e');
    }
  }

  Future<void> _sendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
      _devOtpHint = null;
    });

    try {
      final res = await widget.api.sendPinResetOtp(token: _token);

      if (!mounted) return;
      setState(() {
        if (res.devMode && res.otp != null && res.otp!.isNotEmpty) {
          _devOtpHint = 'OTP mặc định: ${res.otp}';
          _otpCtrl.text = res.otp!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      setState(() => _step = _PinResetStep.newPin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPin() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinCtrl.text.trim() != _confirmPinCtrl.text.trim()) {
      setState(() => _error = 'Mã PIN xác nhận không khớp');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.api.resetPin(
        token: _token,
        otpCode: _otpCtrl.text.trim(),
        newPin: _pinCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt lại PIN thành công')),
      );

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

  String? _validatePin(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Nhập PIN';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(s)) return 'PIN phải đúng 6 chữ số';
    return null;
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt lại mã PIN'),
      ),
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
                const Icon(Icons.lock_reset, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                Text(
                  _step == _PinResetStep.otp
                      ? 'Xác thực OTP'
                      : 'Mã PIN mới',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == _PinResetStep.otp
                      ? 'Nhập OTP đã gửi đến email của bạn'
                      : 'Tạo mã PIN mới',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                        if (_step == _PinResetStep.otp) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mail_outline, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'OTP được gửi đến email của bạn',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_devOtpHint != null) ...[
                            const SizedBox(height: 10),
                            Text(_devOtpHint!, style: const TextStyle(fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'OTP (6 số)',
                              prefixIcon: Icon(Icons.sms_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().length != 6) return 'Nhập OTP 6 số';
                              return null;
                            },
                            enabled: !_loading,
                          ),
                        ],
                        if (_step == _PinResetStep.newPin) ...[
                          TextFormField(
                            controller: _pinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mã PIN mới (6 chữ số)',
                              prefixIcon: Icon(Icons.pin_rounded),
                            ),
                            validator: _validatePin,
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mã PIN',
                              prefixIcon: Icon(Icons.pin_rounded),
                            ),
                            validator: _validatePin,
                            enabled: !_loading,
                          ),
                        ],
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
                          onPressed: _loading
                              ? null
                              : _step == _PinResetStep.otp
                                  ? _verifyOtp
                                  : _resetPin,
                          child: Text(
                            _loading
                                ? 'Đang xử lý...'
                                : _step == _PinResetStep.otp
                                    ? 'Tiếp tục'
                                    : 'Đặt lại PIN',
                          ),
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
