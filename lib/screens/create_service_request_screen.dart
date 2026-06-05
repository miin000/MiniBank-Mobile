import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/service_request_api.dart';
import '../api/authed_api.dart';
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
}

class CreateServiceRequestScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const CreateServiceRequestScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState
    extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requestTypeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController();
  final _picker = ImagePicker();
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
    _requestTypeCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _serviceRequestApi.createServiceRequest(
        requestType: _requestTypeCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        priorityTag: _priorityCtrl.text.trim().isEmpty
            ? null
            : _priorityCtrl.text.trim(),
        payloadJson: await _buildPayloadJson(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi yêu cầu thành công')));
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

  // ── Helpers ──────────────────────────────────────

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle:
          const TextStyle(color: _C.textSecondary, fontSize: 14),
      hintStyle:
          const TextStyle(color: _C.textSecondary, fontSize: 13),
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
          'Gửi yêu cầu dịch vụ',
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
            // ── Request details ──
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
                    controller: _requestTypeCtrl,
                    decoration: _inputDecoration(
                      'Loại yêu cầu',
                      hint: 'vd: limit_change, info_update',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Tiêu đề'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: _inputDecoration('Mô tả'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priorityCtrl,
                    decoration: _inputDecoration(
                        'Mức độ ưu tiên (không bắt buộc)'),
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
                    style: TextStyle(
                        fontSize: 13, color: _C.textSecondary),
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