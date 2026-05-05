import 'package:flutter/material.dart';

import '../auth/auth_api.dart';

enum _PasswordResetStep { phone, otp, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;

  const ForgotPasswordScreen({
    super.key,
    required this.baseUrl,
    required this.api,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _devOtpHint;
  _PasswordResetStep _step = _PasswordResetStep.phone;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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
      final res = await widget.api.sendPasswordResetOtp(
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _step = _PasswordResetStep.otp;
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
      setState(() => _step = _PasswordResetStep.newPassword);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordCtrl.text.trim() != _confirmPasswordCtrl.text.trim()) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.api.resetPassword(
        phone: _phoneCtrl.text.trim(),
        otpCode: _otpCtrl.text.trim(),
        newPassword: _passwordCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đặt lại mật khẩu thành công')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() {
    if (_step == _PasswordResetStep.phone) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step = _PasswordResetStep.phone;
        _error = null;
        _devOtpHint = null;
        _otpCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt lại mật khẩu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
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
                  _step == _PasswordResetStep.phone
                      ? 'Đặt lại mật khẩu'
                      : _step == _PasswordResetStep.otp
                          ? 'Xác thực OTP'
                          : 'Mật khẩu mới',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == _PasswordResetStep.phone
                      ? 'Nhập số điện thoại để nhận OTP'
                      : _step == _PasswordResetStep.otp
                          ? 'Nhập OTP đã gửi đến email của bạn'
                          : 'Nhập mật khẩu mới',
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
                        if (_step == _PasswordResetStep.phone) ...[
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
                            enabled: !_loading,
                          ),
                        ],
                        if (_step == _PasswordResetStep.otp) ...[
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            enabled: false,
                          ),
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
                        if (_step == _PasswordResetStep.newPassword) ...[
                          TextFormField(
                            controller: _passwordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu mới',
                              prefixIcon: Icon(Icons.lock_rounded),
                            ),
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                              if (v.length < 6) return 'Mật khẩu phải ít nhất 6 ký tự';
                              return null;
                            },
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mật khẩu',
                              prefixIcon: Icon(Icons.lock_rounded),
                            ),
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Xác nhận mật khẩu';
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
                              : _step == _PasswordResetStep.phone
                                  ? _sendOtp
                                  : _step == _PasswordResetStep.otp
                                      ? _verifyOtp
                                      : _resetPassword,
                          child: Text(
                            _loading
                                ? 'Đang xử lý...'
                                : _step == _PasswordResetStep.phone
                                    ? 'Gửi OTP'
                                    : _step == _PasswordResetStep.otp
                                        ? 'Tiếp tục'
                                        : 'Đặt lại mật khẩu',
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
