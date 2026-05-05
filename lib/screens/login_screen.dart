import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';
import 'pin_verify_screen.dart';
import 'forgot_password_screen.dart';

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

    setState(() {
      _loading = true;
      _error = null;
      _devOtpHint = null;
    });

    try {
      _deviceId = await widget.identity.getOrCreateDeviceId();
      _publicKeyPem = kIsWeb ? null : await widget.identity.getOrCreatePublicKeyPem();
      final res = await widget.api.sendLoginOtp(
        phone: _phoneCtrl.text.trim(),
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
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _deviceId ??= await widget.identity.getOrCreateDeviceId();
      _publicKeyPem ??= kIsWeb ? null : await widget.identity.getOrCreatePublicKeyPem();
      final res = await widget.api.verifyLogin(
        phone: _phoneCtrl.text.trim(),
        otpCode: _otpCtrl.text.trim(),
        deviceId: _deviceId!,
        publicKeyPem: _publicKeyPem,
      );

      await widget.storage.save(token: res.accessToken, user: res.user);

      if (!mounted) return;
      
      // Check if user has PIN set by trying to verify an empty PIN
      try {
        await widget.api.verifyPin('000000', res.accessToken);
        if (!mounted) return;
        // If we get here, empty PIN worked (shouldn't happen), go to home
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
        if (e.toString().contains('PIN_NOT_SET')) {
          // PIN not set, show PIN setup screen
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PinSetupScreen(
                baseUrl: widget.baseUrl,
                api: widget.api,
                storage: widget.storage,
                identity: widget.identity,
              ),
            ),
          );
        } else {
          // PIN is set, show PIN verify screen
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PinVerifyScreen(
                baseUrl: widget.baseUrl,
                api: widget.api,
                storage: widget.storage,
                identity: widget.identity,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _goBackToCredentials() {
    setState(() {
      _step = _LoginStep.credentials;
      _error = null;
      _devOtpHint = null;
      _otpCtrl.clear();
    });
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 38),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'MiniBank',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chào mừng trở lại',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đăng nhập để tiếp tục quản lý tài chính của bạn.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
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
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: Icon(Icons.phone_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nhập số điện thoại';
                            return null;
                          },
                          enabled: !_loading && _step == _LoginStep.credentials,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: Icon(Icons.lock_rounded),
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                            return null;
                          },
                          enabled: !_loading && _step == _LoginStep.credentials,
                        ),
                        if (_step == _LoginStep.credentials)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ForgotPasswordScreen(
                                            baseUrl: widget.baseUrl,
                                            api: widget.api,
                                          ),
                                        ),
                                      );
                                    },
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                        if (_step == _LoginStep.otp) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_outlined, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Đã gửi OTP đến số ${_phoneCtrl.text.trim()}.',
                                    style: const TextStyle(fontSize: 13),
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
                              if (_step != _LoginStep.otp) return null;
                              if (v == null || v.trim().length != 6) return 'Nhập OTP 6 số';
                              return null;
                            },
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
                              style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                            ),
                          ),
                        if (_error != null) const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : _step == _LoginStep.credentials
                                  ? _sendOtp
                                  : _verifyLogin,
                          child: Text(
                            _loading
                                ? (_step == _LoginStep.credentials ? 'Đang gửi OTP...' : 'Đang xác thực...')
                                : (_step == _LoginStep.credentials ? 'Tiếp tục' : 'Xác thực và vào ứng dụng'),
                          ),
                        ),
                        if (_step == _LoginStep.otp) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _loading ? null : _goBackToCredentials,
                            child: const Text('Đổi số điện thoại hoặc mật khẩu'),
                          ),
                        ],
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RegisterScreen(
                                        baseUrl: widget.baseUrl,
                                        api: widget.api,
                                        storage: widget.storage,
                                        identity: widget.identity,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Tạo tài khoản mới'),
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
