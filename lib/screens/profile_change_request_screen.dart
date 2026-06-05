import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/authed_api.dart';
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
  static const infoBg = Color(0xFFEFF4FF);
  static const infoBorder = Color(0xFFBFD0F7);
}

class ProfileChangeRequestScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const ProfileChangeRequestScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<ProfileChangeRequestScreen> createState() =>
      _ProfileChangeRequestScreenState();
}

class _ProfileChangeRequestScreenState
    extends State<ProfileChangeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _dob;
  XFile? _cccdFront;
  XFile? _cccdBack;
  bool _submitting = false;

  late ServiceRequestApi _serviceRequestApi;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _serviceRequestApi = ServiceRequestApi(api: api);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime? value) {
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().padLeft(4, '0')}';
  }

  String? _serializeDob(DateTime? value) {
    if (value == null) return null;
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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
        'base64': base64Encode(bytes),
      };
    }

    return jsonEncode({
      'cccdFront': await encodeFile(_cccdFront),
      'cccdBack': await encodeFile(_cccdBack),
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nameCtrl.text.trim().isEmpty &&
        _addressCtrl.text.trim().isEmpty &&
        _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vui lòng nhập ít nhất một thông tin cần đổi')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _serviceRequestApi.createProfileChangeRequest(
        fullName: _nameCtrl.text.trim(),
        dob: _serializeDob(_dob),
        address: _addressCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
        payloadJson: await _buildPayloadJson(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi yêu cầu đổi thông tin')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Shared helpers ──────────────────────────────

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle:
          const TextStyle(color: _C.textSecondary, fontSize: 14),
      hintStyle:
          const TextStyle(color: _C.textSecondary, fontSize: 14),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary),
        ),
      );

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
            color: hasFile
                ? _C.blue.withValues(alpha: 0.4)
                : const Color(0xFFCDD1DC),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFile
                  ? Icons.check_circle_rounded
                  : Icons.badge_outlined,
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
          'Yêu cầu đổi thông tin',
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── New info fields ──
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
                  _sectionLabel('Thông tin mới'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration(
                      'Họ và tên mới',
                      hint: 'Nhập họ và tên mới (nếu muốn đổi)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // DOB picker
                  GestureDetector(
                    onTap: _pickDob,
                    child: Container(
                      height: 52,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _C.inputFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dob == null
                                ? 'Ngày sinh mới'
                                : _formatDob(_dob),
                            style: TextStyle(
                              fontSize: 14,
                              color: _dob == null
                                  ? _C.textSecondary
                                  : _C.textPrimary,
                            ),
                          ),
                          const Icon(Icons.calendar_today_rounded,
                              size: 17, color: _C.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: _inputDecoration(
                      'Địa chỉ mới',
                      hint: 'Nhập địa chỉ mới (nếu muốn đổi)',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonCtrl,
                    decoration: _inputDecoration(
                        'Lý do (không bắt buộc)'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Giấy tờ xác minh'),
                  const Text(
                    'Vui lòng tải lên ảnh CCCD/CMND để xác minh',
                    style:
                        TextStyle(fontSize: 13, color: _C.textSecondary),
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
                ],
              ),
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Gửi yêu cầu',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}