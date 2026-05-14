import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'home_screen.dart';

const _blue = Color(0xFF1B4FD8);
const _gray200 = Color(0xFFE5E7EB);
const _gray400 = Color(0xFF9CA3AF);
const _gray900 = Color(0xFF111827);

class RegisterScreen extends StatefulWidget {
  final String baseUrl;
  final AuthApi api;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const RegisterScreen({
    super.key,
    required this.baseUrl,
    required this.api,
    required this.storage,
    required this.identity,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final deviceId = await widget.identity.getOrCreateDeviceId();
      final publicKeyPem = kIsWeb ? null : await widget.identity.getOrCreatePublicKeyPem();
      final res = await widget.api.register(
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        deviceId: deviceId,
        fullName: _fullNameCtrl.text.trim().isEmpty ? null : _fullNameCtrl.text.trim(),
        publicKeyPem: publicKeyPem,
      );
      await widget.storage.save(token: res.accessToken, user: res.user);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(
            baseUrl: widget.baseUrl, api: widget.api,
            storage: widget.storage, identity: widget.identity)),
        (route) => false,
      );
    } catch (e) {
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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 24),

              // Header row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text('Tạo tài khoản',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),

              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('Bắt đầu hành trình tài chính của bạn',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 12)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FormLabel('Số điện thoại *'),
                      const SizedBox(height: 6),
                      _FormField(
                        controller: _phoneCtrl,
                        hint: '0901 234 567',
                        keyboardType: TextInputType.phone,
                        prefix: Icons.phone_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập số điện thoại' : null,
                      ),
                      const SizedBox(height: 14),

                      _FormLabel('Email *'),
                      const SizedBox(height: 6),
                      _FormField(
                        controller: _emailCtrl,
                        hint: 'example@email.com',
                        keyboardType: TextInputType.emailAddress,
                        prefix: Icons.mail_rounded,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập email';
                          if (!v.contains('@')) return 'Email không hợp lệ';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _FormLabel('Họ và tên'),
                      const SizedBox(height: 6),
                      _FormField(
                        controller: _fullNameCtrl,
                        hint: 'Nguyễn Văn A (tuỳ chọn)',
                        prefix: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),

                      _FormLabel('Mật khẩu *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: _inputDeco(
                          hint: 'Tối thiểu 6 ký tự',
                          prefix: Icons.lock_rounded,
                          suffix: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 18, color: _gray400),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                          if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                          return null;
                        },
                      ),

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
                              Expanded(child: Text(_error!,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      SizedBox(
                        width: double.infinity, height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Tạo tài khoản',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Center(
                        child: Text.rich(
                          const TextSpan(
                            text: 'Bằng cách tạo tài khoản, bạn đồng ý với ',
                            style: TextStyle(fontSize: 12, color: _gray400),
                            children: [
                              TextSpan(text: 'Điều khoản sử dụng', style: TextStyle(color: _blue)),
                              TextSpan(text: ' của MiniBank.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _gray400, fontSize: 14),
      prefixIcon: Icon(prefix, size: 18, color: _gray400),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gray200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gray200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gray900));
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _gray400, fontSize: 14),
        prefixIcon: Icon(prefix, size: 18, color: _gray400),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gray200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gray200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      ),
      validator: validator,
    );
  }
}