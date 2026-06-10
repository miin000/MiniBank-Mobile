import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';
import 'pin_verify_screen.dart';
import 'forgot_password_screen.dart';

const _blue = Color(0xFF1B4FD8);
const _gray200 = Color(0xFFE5E7EB);
const _gray400 = Color(0xFF9CA3AF);
const _gray900 = Color(0xFF111827);

enum _LoginStep { credentials, otp }

class LoginScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const LoginScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  String? _devOtpHint;
  _LoginStep _step = _LoginStep.credentials;
  String? _deviceId;
  String? _publicKeyPem;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _devOtpHint = null; });
    try {
      _deviceId = await widget.identity.getOrCreateDeviceId();
      // Sending OTP only needs the stable device id. Avoid generating key material here
      // because some emulator/mobile crypto paths can throw before the network call starts.
      _publicKeyPem = null;
      final res = await widget.api.sendLoginOtp(
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        deviceId: _deviceId!,
        publicKeyPem: _publicKeyPem,
      );
      if (!mounted) return;
      setState(() {
        _step = _LoginStep.otp;
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

  Future<void> _verifyLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      _deviceId ??= await widget.identity.getOrCreateDeviceId();
      _publicKeyPem ??= null;
      final res = await widget.api.verifyLogin(
        phone: _phoneCtrl.text.trim(),
        otpCode: _otpCtrl.text.trim(),
        deviceId: _deviceId!,
        publicKeyPem: _publicKeyPem,
      );
      await widget.storage.save(token: res.accessToken, user: res.user);
      if (!mounted) return;

      try {
        await widget.api.verifyPin('000000', res.accessToken);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => HomeScreen(baseUrl: widget.baseUrl, api: widget.api,
                storage: widget.storage, identity: widget.identity)));
      } catch (e) {
        if (e.toString().contains('PIN_NOT_SET')) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => PinSetupScreen(baseUrl: widget.baseUrl, api: widget.api,
                  storage: widget.storage, identity: widget.identity)));
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => PinVerifyScreen(baseUrl: widget.baseUrl, api: widget.api,
                  storage: widget.storage, identity: widget.identity)));
        }
      }
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
            colors: [Color(0xFF0D2E82), Color(0xFF1B4FD8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(top: -60, right: -40,
              child: _Circle(size: 200, opacity: 0.07)),
            Positioned(top: 80, right: 60,
              child: _Circle(size: 120, opacity: 0.05)),
            Positioned(bottom: 200, left: -60,
              child: _Circle(size: 180, opacity: 0.06)),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('MiniBank',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      ],
                    ),

                    const SizedBox(height: 40),

                    const Text('Chào mừng trở lại',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2)),
                    const SizedBox(height: 6),
                    const Text('Đăng nhập để quản lý tài chính của bạn.',
                        style: TextStyle(color: Colors.white70, fontSize: 15)),

                    const SizedBox(height: 32),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Step indicator
                            if (_step == _LoginStep.otp) ...[
                              _StepBadge(label: 'Bước 2/2 — Xác thực OTP'),
                              const SizedBox(height: 16),
                            ],

                            // Phone
                            _FormLabel('Số điện thoại'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              enabled: !_loading && _step == _LoginStep.credentials,
                              decoration: _inputDecoration(
                                hint: 'Nhập số điện thoại',
                                prefix: const Icon(Icons.phone_rounded, size: 18, color: _gray400),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập số điện thoại' : null,
                            ),
                            const SizedBox(height: 14),

                            // Password
                            _FormLabel('Mật khẩu'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              enabled: !_loading && _step == _LoginStep.credentials,
                              decoration: _inputDecoration(
                                hint: 'Nhập mật khẩu',
                                prefix: const Icon(Icons.lock_rounded, size: 18, color: _gray400),
                                suffix: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      size: 18, color: _gray400),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                            ),

                            if (_step == _LoginStep.credentials) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ForgotPasswordScreen(
                                        baseUrl: widget.baseUrl, api: widget.api))),
                                  style: TextButton.styleFrom(foregroundColor: _blue, padding: EdgeInsets.zero),
                                  child: const Text('Quên mật khẩu?', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],

                            // OTP
                            if (_step == _LoginStep.otp) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.sms_rounded, size: 16, color: _blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'OTP đã gửi đến ${_phoneCtrl.text.trim()}',
                                        style: const TextStyle(fontSize: 13, color: _blue),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_devOtpHint != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Text(_devOtpHint!,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontFamily: 'monospace')),
                                ),
                              ],
                              const SizedBox(height: 14),
                              _FormLabel('Mã OTP (6 số)'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                enabled: !_loading,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 10),
                                textAlign: TextAlign.center,
                                decoration: _inputDecoration(hint: '• • • • • •').copyWith(
                                  counterText: '',
                                  hintStyle: const TextStyle(fontSize: 20, letterSpacing: 8, color: _gray200),
                                ),
                                validator: (v) {
                                  if (_step != _LoginStep.otp) return null;
                                  return (v == null || v.trim().length != 6) ? 'Nhập OTP 6 số' : null;
                                },
                              ),
                            ],

                            const SizedBox(height: 20),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_error!,
                                          style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C))),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Main CTA
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: FilledButton(
                                onPressed: _loading ? null
                                    : _step == _LoginStep.credentials ? _sendOtp : _verifyLogin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        _step == _LoginStep.credentials ? 'Tiếp tục' : 'Đăng nhập',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),

                            if (_step == _LoginStep.otp) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: _loading ? null : () => setState(() {
                                    _step = _LoginStep.credentials;
                                    _error = null; _devOtpHint = null; _otpCtrl.clear();
                                  }),
                                  child: const Text('Đổi số điện thoại', style: TextStyle(color: _gray400)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Register
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Chưa có tài khoản?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          TextButton(
                            onPressed: _loading ? null : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => RegisterScreen(baseUrl: widget.baseUrl, api: widget.api,
                                    storage: widget.storage, identity: widget.identity))),
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            child: const Text('Đăng ký ngay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _gray400, fontSize: 14),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gray900));
}

class _StepBadge extends StatelessWidget {
  final String label;
  const _StepBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF2FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w500)),
  );
}