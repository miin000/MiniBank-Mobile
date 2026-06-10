import 'dart:async';

import 'package:flutter/material.dart';

import '../api/account_api.dart';
import '../auth/auth_storage.dart';

class AccountSetupScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const AccountSetupScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _desiredCtrl = TextEditingController();

  bool _loading = false;
  bool _generateCooldown = false;
  bool _hasGeneratedSuggestions = false;
  Timer? _cooldownTimer;
  String? _error;
  List<String> _suggestions = const [];
  String? _selectedAccountNumber;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _desiredCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestions() async {
    if (_generateCooldown) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _selectedAccountNumber = null;
      _suggestions = const [];
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final data = await api.suggestions(desired: _desiredCtrl.text.trim(), limit: 10);
      if (!mounted) return;
      setState(() {
        _suggestions = data.suggestions;
        _hasGeneratedSuggestions = true;
        if (_suggestions.isNotEmpty) {
          _selectedAccountNumber = _suggestions.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _generateCooldown = true;
        });
        _cooldownTimer?.cancel();
        _cooldownTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _generateCooldown = false);
        });
      }
    }
  }

  Future<void> _createAccount() async {
    final selected = _selectedAccountNumber;
    if (selected == null || selected.isEmpty) {
      setState(() => _error = 'Vui long chon so tai khoan.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await api.createMyAccount(accountNumber: selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da tao tai khoan thanh cong.')),
      );
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Tao so tai khoan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Nhap 6-8 so mong muon. He thong se chen so ngau nhien de tao day 13 so duy nhat.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _desiredCtrl,
              decoration: const InputDecoration(
                labelText: 'Day so mong muon (6-8 so)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) return 'Nhap day so mong muon';
                if (!RegExp(r'^[0-9]{6,8}$').hasMatch(raw)) {
                  return 'Day so phai tu 6 den 8 chu so';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: (_loading || _generateCooldown) ? null : _generateSuggestions,
                  child: Text(_loading
                      ? 'Dang sinh...'
                      : _generateCooldown
                          ? 'Vui long cho...'
                          : _hasGeneratedSuggestions
                              ? 'Danh sach moi'
                              : 'Tao so tai khoan'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Chon so tai khoan', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._suggestions.map(
              (accNo) => ListTile(
                onTap: _loading
                    ? null
                    : () {
                        setState(() => _selectedAccountNumber = accNo);
                      },
                leading: Icon(
                  _selectedAccountNumber == accNo
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(accNo),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _createAccount,
              child: Text(_loading ? 'Dang tao tai khoan...' : 'Xac nhan tao tai khoan'),
            ),
          ],
        ],
      ),
    );
  }
}
