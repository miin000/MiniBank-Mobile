import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/authed_api.dart';
import '../api/profile_api.dart';
import '../api/service_request_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class _C {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAF0);
  static const textPrimary = Color(0xFF0D1B3E);
  static const textSecondary = Color(0xFF6B7299);
  static const blue = Color(0xFF2563EB);
  static const inputFill = Color(0xFFF3F5FA);
  static const divider = Color(0xFFEEF0F5);
}

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
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  XFile? _cccdFront;
  XFile? _cccdBack;

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
      final profileApi =
          ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
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
        requestedDailyTransferLimit:
            _limitCtrl.text.trim().replaceAll('.', ''),
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
        payloadJson: await _buildPayloadJson(),
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

  Future<void> _pickCccd(bool front) async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (front) {
          _cccdFront = picked;
        } else {
          _cccdBack = picked;
        }
      });
    }
  }

  Future<String?> _buildPayloadJson() async {
    if (_cccdFront == null && _cccdBack == null) return null;
    Future<Map<String, String>?> encodeFile(XFile? file) async {
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return {
        'fileName': file.name,
        'mimeType': file.mimeType ?? 'image/jpeg',
        'base64': base64Encode(bytes)
      };
    }

    return jsonEncode({
      'cccdFront': await encodeFile(_cccdFront),
      'cccdBack': await encodeFile(_cccdBack)
    });
  }

  // ── Widgets ──────────────────────────────────────

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 14),
      filled: true,
      fillColor: _C.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary),
      ),
    );
  }

  Widget _cccdSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Giấy tờ xác minh'),
      const Text(
        'Vui lòng tải lên ảnh CCCD/CMND để xác minh',
        style: TextStyle(fontSize: 13, color: _C.textSecondary),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _cccdUploadBox(
            label: 'Mặt trước',
            file: _cccdFront,
            onTap: () => _pickCccd(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _cccdUploadBox(
            label: 'Mặt sau',
            file: _cccdBack,
            onTap: () => _pickCccd(false),
          ),
        ),
      ]),
    ]);
  }

  Widget _cccdUploadBox({
    required String label,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: hasFile
              ? _C.blue.withValues(alpha: 0.05)
              : _C.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? _C.blue.withValues(alpha: 0.4) : _C.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.badge_outlined,
              color: hasFile ? _C.blue : _C.textSecondary,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              hasFile ? file!.name : label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: hasFile ? _C.blue : _C.textSecondary,
                fontWeight:
                    hasFile ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Yêu cầu nâng hạn mức',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _C.blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_outlined,
                          size: 40, color: _C.textSecondary),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _C.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _loadAccounts,
                          child: const Text('Thử lại')),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // ── Account selection ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _C.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Chọn tài khoản'),
                            if (_accounts.isEmpty)
                              const Text('Không có tài khoản khả dụng',
                                  style:
                                      TextStyle(color: _C.textSecondary))
                            else
                              ..._accounts.map((acc) => InkWell(
                                    onTap: () => setState(
                                        () => _selectedAccount = acc),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 4),
                                      child: Row(children: [
                                        Radio<int>(
                                          value: acc.id,
                                          groupValue:
                                              _selectedAccount?.id,
                                          onChanged: (_) => setState(
                                              () => _selectedAccount =
                                                  acc),
                                          activeColor: _C.blue,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(acc.accountName,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color:
                                                        _C.textPrimary)),
                                            const SizedBox(height: 2),
                                            Text(acc.accountNumber,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        _C.textSecondary)),
                                          ],
                                        )),
                                      ]),
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Limit & reason ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _C.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Thông tin yêu cầu'),
                            TextFormField(
                              controller: _limitCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: _inputDecoration(
                                  'Hạn mức mong muốn (VNĐ)'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Vui lòng nhập hạn mức';
                                }
                                final raw = v.replaceAll('.', '');
                                final n = double.tryParse(raw);
                                if (n == null || n <= 0) {
                                  return 'Hạn mức không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reasonCtrl,
                              decoration:
                                  _inputDecoration('Lý do (không bắt buộc)'),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── CCCD upload ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _C.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.border),
                        ),
                        child: _cccdSection(),
                      ),
                      const SizedBox(height: 24),

                      // ── Submit ──
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _C.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Text(
                                  'Gửi yêu cầu',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
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