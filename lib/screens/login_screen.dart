import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_storage.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthApi api;
  final AuthStorage storage;

  const LoginScreen({super.key, required this.api, required this.storage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.api.login(
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      await widget.storage.save(token: res.accessToken, user: res.user);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(api: widget.api, storage: widget.storage),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập số điện thoại';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Mật khẩu'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nhập mật khẩu';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              if (_error != null) const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Đang đăng nhập...' : 'Đăng nhập'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(
                              api: widget.api,
                              storage: widget.storage,
                            ),
                          ),
                        );
                      },
                child: const Text('Đăng ký tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
