import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../api/kyc_api.dart';
import '../api/profile_api.dart';
import '../auth/auth_storage.dart';
import '../config/app_config.dart';

class KycScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const KycScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _citizenIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _monthlyIncomeCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _picker = ImagePicker();

  String? _citizenFrontImageUrl;
  String? _citizenBackImageUrl;
  String? _portraitImageUrl;

  bool _uploadingFront = false;
  bool _uploadingBack = false;
  bool _uploadingPortrait = false;
  bool _kycLocked = false;
  String? _status;

  bool _loading = false;
  bool _sendingOtp = false;
  String? _error;
  String? _phone;
  String? _devOtpHint;

  @override
  void initState() {
    super.initState();
    widget.storage.getUser().then((u) {
      if (!mounted) return;
      setState(() => _phone = u?.phone);
    });
    _loadProfileStatus();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _citizenIdCtrl.dispose();
    _addressCtrl.dispose();
    _occupationCtrl.dispose();
    _monthlyIncomeCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileStatus() async {
    try {
      final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final profile = await api.me();
      if (!mounted) return;
      final status = profile.status?.toLowerCase();
      setState(() {
        _status = profile.status;
        _kycLocked = status == 'active';
      });
    } catch (_) {
      // Ignore profile lookup errors here; KYC submit endpoint will validate.
    }
  }

  bool _ensureCloudinaryConfigured() {
    if (AppConfig.cloudinaryCloudName.isEmpty || AppConfig.cloudinaryUploadPreset.isEmpty) {
      setState(() => _error = 'Chua cau hinh Cloudinary (CLOUDINARY_CLOUD_NAME, CLOUDINARY_UPLOAD_PRESET).');
      return false;
    }
    return true;
  }

  Future<String> _uploadToCloudinary(XFile file) async {
    final cloudName = AppConfig.cloudinaryCloudName;
    final preset = AppConfig.cloudinaryUploadPreset;
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..fields['folder'] = 'minibank/kyc'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload that bai: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Khong lay duoc URL anh');
    }
    return url;
  }

  Future<void> _pickAndUpload({
    required void Function(String url) onUploaded,
    required void Function(bool uploading) onUploading,
  }) async {
    if (!_ensureCloudinaryConfigured()) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    onUploading(true);
    setState(() => _error = null);
    try {
      final url = await _uploadToCloudinary(picked);
      if (!mounted) return;
      onUploaded(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) onUploading(false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      initialDate: DateTime(now.year - 20, now.month, now.day),
    );
    if (picked == null) return;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    _dobCtrl.text = '$yyyy-$mm-$dd';
  }

  Future<void> _sendOtp() async {
    if (_kycLocked) {
      setState(() => _error = 'Tai khoan da duoc duyet KYC.');
      return;
    }
    setState(() {
      _sendingOtp = true;
      _error = null;
      _devOtpHint = null;
    });

    try {
      final api = KycApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.sendOtp();
      if (!mounted) return;
      setState(() {
        if (res.devMode && res.otp != null) {
          _devOtpHint = 'OTP mac dinh: ${res.otp}';
        } else {
          _devOtpHint = 'OTP da duoc gui qua SMS.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _submit() async {
    if (_kycLocked) {
      setState(() => _error = 'Tai khoan da duoc duyet KYC.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_citizenFrontImageUrl == null || _citizenFrontImageUrl!.isEmpty) {
      setState(() => _error = 'Vui long tai anh CCCD mat truoc.');
      return;
    }
    if (_citizenBackImageUrl == null || _citizenBackImageUrl!.isEmpty) {
      setState(() => _error = 'Vui long tai anh CCCD mat sau.');
      return;
    }
    if (_portraitImageUrl == null || _portraitImageUrl!.isEmpty) {
      setState(() => _error = 'Vui long tai anh chan dung.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = KycApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await api.submit(
        fullName: _fullNameCtrl.text.trim(),
        dobIso: _dobCtrl.text.trim(),
        citizenId: _citizenIdCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        occupation: _occupationCtrl.text.trim(),
        monthlyIncome: _monthlyIncomeCtrl.text.trim(),
        citizenFrontImageUrl: _citizenFrontImageUrl ?? '',
        citizenBackImageUrl: _citizenBackImageUrl ?? '',
        portraitImageUrl: _portraitImageUrl ?? '',
        otpCode: _otpCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da gui KYC. Vui long cho duyet.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildUploadField({
    required String label,
    required String? imageUrl,
    required bool uploading,
    required VoidCallback onPick,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: const Text('Chua co anh', style: TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: uploading ? null : onPick,
            child: Text(uploading ? 'Dang tai...' : 'Chon anh tu may'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xac thuc KYC')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_kycLocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFEFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: Text(
                'KYC da duoc duyet${_status != null ? ' (Trang thai: $_status)' : ''}.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text('So dien thoai: ${_phone ?? ''}'),
          ),
          const SizedBox(height: 12),
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
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thong tin ca nhan', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Ho va ten'),
                    enabled: !_kycLocked,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhap ho va ten' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Ngay sinh (yyyy-mm-dd)'),
                    onTap: _kycLocked ? null : _pickDob,
                    enabled: !_kycLocked,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Chon ngay sinh' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _citizenIdCtrl,
                    decoration: const InputDecoration(labelText: 'So CCCD'),
                    enabled: !_kycLocked,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhap so CCCD' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Dia chi'),
                    maxLines: 2,
                    enabled: !_kycLocked,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhap dia chi' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _occupationCtrl,
                    decoration: const InputDecoration(labelText: 'Nghe nghiep'),
                    enabled: !_kycLocked,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhap nghe nghiep' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _monthlyIncomeCtrl,
                    decoration: const InputDecoration(labelText: 'Thu nhap thang (VND)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_kycLocked,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nhap thu nhap thang';
                      final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) return 'Thu nhap khong hop le';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildUploadField(
                    label: 'Anh CCCD mat truoc',
                    imageUrl: _citizenFrontImageUrl,
                    uploading: _uploadingFront || _kycLocked,
                    onPick: () => _pickAndUpload(
                      onUploaded: (url) => setState(() => _citizenFrontImageUrl = url),
                      onUploading: (v) => setState(() => _uploadingFront = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildUploadField(
                    label: 'Anh CCCD mat sau',
                    imageUrl: _citizenBackImageUrl,
                    uploading: _uploadingBack || _kycLocked,
                    onPick: () => _pickAndUpload(
                      onUploaded: (url) => setState(() => _citizenBackImageUrl = url),
                      onUploading: (v) => setState(() => _uploadingBack = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildUploadField(
                    label: 'Anh chan dung',
                    imageUrl: _portraitImageUrl,
                    uploading: _uploadingPortrait || _kycLocked,
                    onPick: () => _pickAndUpload(
                      onUploaded: (url) => setState(() => _portraitImageUrl = url),
                      onUploading: (v) => setState(() => _uploadingPortrait = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xac thuc OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sendingOtp || _kycLocked ? null : _sendOtp,
                        child: Text(_sendingOtp ? 'Dang gui OTP...' : 'Gui OTP'),
                      ),
                    ),
                  ],
                ),
                if (_devOtpHint != null) ...[
                  const SizedBox(height: 8),
                  Text(_devOtpHint!, style: const TextStyle(fontSize: 12)),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otpCtrl,
                  decoration: const InputDecoration(labelText: 'OTP (6 so)'),
                  keyboardType: TextInputType.number,
                  enabled: !_kycLocked,
                  validator: (v) => v == null || v.trim().length != 6 ? 'Nhap OTP 6 so' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading || _kycLocked ? null : _submit,
            child: Text(_loading ? 'Dang gui KYC...' : 'Gui KYC'),
          ),
        ],
      ),
    );
  }
}
