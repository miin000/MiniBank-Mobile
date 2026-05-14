import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/authed_api.dart';
import '../api/profile_api.dart';
import '../api/service_request_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class LimitChangeRequestScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const LimitChangeRequestScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<LimitChangeRequestScreen> createState() => _LimitChangeRequestScreenState();
}

class _LimitChangeRequestScreenState extends State<LimitChangeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limitCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<ProfileAccountSummary> _accounts = [];
  ProfileAccountSummary? _selectedAccount;

  late ServiceRequestApi _serviceRequestApi;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _serviceRequestApi = ServiceRequestApi(api: api);
    _loadAccounts();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileApi = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final profile = await profileApi.me();
      final accounts = profile.accounts
          .where((a) => a.status.toLowerCase() == 'active')
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _accounts = accounts;
          if (_accounts.isNotEmpty) _selectedAccount = _accounts.first;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) return;

    setState(() => _submitting = true);
    try {
      await _serviceRequestApi.createLimitChangeRequest(
        accountId: _selectedAccount!.id,
        requestedDailyTransferLimit: _limitCtrl.text.trim().replaceAll('.', ''),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu nâng hạn mức')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu nâng hạn mức')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadAccounts, child: const Text('Thử lại')),
                      ],
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        const Text('Chọn tài khoản',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_accounts.isEmpty)
                          const Text('Không có tài khoản khả dụng')
                        else
                          ..._accounts.map((acc) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Radio<int>(
                                  value: acc.id,
                                  groupValue: _selectedAccount?.id,
                                  onChanged: (_) {
                                    setState(() => _selectedAccount = acc);
                                  },
                                ),
                                title: Text(acc.accountName),
                                subtitle: Text(acc.accountNumber),
                                onTap: () => setState(() => _selectedAccount = acc),
                              )),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _limitCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Hạn mức mong muốn (VNĐ)',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Vui lòng nhập hạn mức';
                            }
                            final raw = v.replaceAll('.', '');
                            final n = double.tryParse(raw);
                            if (n == null || n <= 0) return 'Hạn mức không hợp lệ';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Lý do (không bắt buộc)',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting ? 'Đang gửi...' : 'Gửi yêu cầu'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
