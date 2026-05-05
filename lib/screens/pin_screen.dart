import 'package:flutter/material.dart';

import '../api/profile_api.dart';
import '../auth/auth_storage.dart';

class PinScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final bool hasExistingPin;

  const PinScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.hasExistingPin,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await api.setOrChangePin(
        oldPin: widget.hasExistingPin ? _oldCtrl.text.trim() : null,
        newPin: _newCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật PIN thành công')),
      );
      Navigator.of(context).pop();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN giao dịch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.hasExistingPin) ...[
                TextFormField(
                  controller: _oldCtrl,
                  decoration: const InputDecoration(labelText: 'PIN cũ'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: _validatePin,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _newCtrl,
                decoration: const InputDecoration(labelText: 'PIN mới (6 số)'),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: _validatePin,
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 13)),
                ),
              if (_error != null) const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Đang xử lý...' : 'Xác nhận'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
