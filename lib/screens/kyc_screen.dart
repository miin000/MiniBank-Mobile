import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../api/kyc_api.dart';
import '../api/profile_api.dart';
import '../auth/auth_storage.dart';
import '../config/app_config.dart';

const _blue = Color(0xFF1B4FD8);
const _blueLight = Color(0xFFEEF2FF);
const _green = Color(0xFF16A34A);
const _gray100 = Color(0xFFF3F4F6);
const _gray200 = Color(0xFFE5E7EB);
const _gray400 = Color(0xFF9CA3AF);
const _gray600 = Color(0xFF4B5563);
const _gray900 = Color(0xFF111827);

class KycScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const KycScreen({super.key, required this.baseUrl, required this.storage});

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
  bool _kycPending = false;
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
        // New users are stored as "pending" before KYC, so do not lock the form
        // from user.status alone. Backend still prevents duplicate KYC requests.
        _kycLocked = status == 'active';
        _kycPending = false;
      });
    } catch (_) {}
  }

  bool _ensureCloudinaryConfigured() {
    if (AppConfig.cloudinaryCloudName.isEmpty || AppConfig.cloudinaryUploadPreset.isEmpty) {
      setState(() => _error = 'Chưa cấu hình Cloudinary.');
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
      ..fields['folder'] = 'minibank/kyc';
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: file.name.isNotEmpty ? file.name : 'kyc.jpg'));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload thất bại: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url']?.toString();
    if (url == null || url.isEmpty) throw Exception('Không lấy được URL ảnh');
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
      initialDate: DateTime(now.year - 25, now.month, now.day),
    );
    if (picked == null) return;
    _dobCtrl.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOtp() async {
    if (_kycLocked) { setState(() => _error = _kycPending ? 'Bạn đã gửi yêu cầu KYC. Vui lòng chờ admin duyệt.' : 'Tài khoản đã được duyệt KYC.'); return; }
    setState(() { _sendingOtp = true; _error = null; _devOtpHint = null; });
    try {
      final api = KycApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.sendOtp();
      if (!mounted) return;
      setState(() {
        _devOtpHint = (res.devMode && res.otp != null) ? 'OTP mặc định: ${res.otp}' : 'OTP đã gửi qua SMS.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _submit() async {
    if (_kycLocked) { setState(() => _error = _kycPending ? 'Bạn đã gửi yêu cầu KYC. Vui lòng chờ admin duyệt.' : 'Tài khoản đã được duyệt KYC.'); return; }
    final missingFields = <String>[];
    if (_fullNameCtrl.text.trim().isEmpty) missingFields.add('Họ và tên');
    if (_dobCtrl.text.trim().isEmpty) missingFields.add('Ngày sinh');
    if (_citizenIdCtrl.text.trim().isEmpty) missingFields.add('Số CCCD');
    if (_addressCtrl.text.trim().isEmpty) missingFields.add('Địa chỉ');
    if (_occupationCtrl.text.trim().isEmpty) missingFields.add('Nghề nghiệp');
    if (_monthlyIncomeCtrl.text.trim().isEmpty) missingFields.add('Thu nhập hàng tháng');
    if (_otpCtrl.text.trim().isEmpty) missingFields.add('Mã OTP');
    if (_citizenFrontImageUrl == null) missingFields.add('Ảnh CCCD mặt trước');
    if (_citizenBackImageUrl == null) missingFields.add('Ảnh CCCD mặt sau');
    if (_portraitImageUrl == null) missingFields.add('Ảnh chân dung');
    if (missingFields.isNotEmpty) {
      debugPrint('[KYC] Missing required fields: ${missingFields.join(', ')}');
    }
    if (!_formKey.currentState!.validate()) return;
    if (_citizenFrontImageUrl == null) { setState(() => _error = 'Vui lòng tải ảnh CCCD mặt trước.'); return; }
    if (_citizenBackImageUrl == null) { setState(() => _error = 'Vui lòng tải ảnh CCCD mặt sau.'); return; }
    if (_portraitImageUrl == null) { setState(() => _error = 'Vui lòng tải ảnh chân dung.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final api = KycApi(baseUrl: widget.baseUrl, storage: widget.storage);
      await api.submit(
        fullName: _fullNameCtrl.text.trim(), dobIso: _dobCtrl.text.trim(),
        citizenId: _citizenIdCtrl.text.trim(), address: _addressCtrl.text.trim(),
        occupation: _occupationCtrl.text.trim(), monthlyIncome: _monthlyIncomeCtrl.text.trim(),
        citizenFrontImageUrl: _citizenFrontImageUrl ?? '', citizenBackImageUrl: _citizenBackImageUrl ?? '',
        portraitImageUrl: _portraitImageUrl ?? '', otpCode: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã gửi KYC. Vui lòng chờ duyệt.'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pop();
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: _gray900),
        title: const Text('Xác thực KYC',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _gray900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          if (_kycPending)
            _InfoBanner(
              icon: Icons.hourglass_top_rounded,
              message: 'Bạn đã gửi yêu cầu KYC. Vui lòng chờ admin duyệt trước khi gửi lại.',
              color: const Color(0xFFD97706),
              bgColor: const Color(0xFFFFF7ED),
            )
          else if (_kycLocked)
            _InfoBanner(
              icon: Icons.verified_rounded,
              message: 'KYC đã được duyệt${_status != null ? ' • Trạng thái: $_status' : ''}.',
              color: _green,
              bgColor: const Color(0xFFF0FDF4),
            )
          else
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              message: 'Điền đầy đủ thông tin để xác thực tài khoản. Sau khi gửi, admin sẽ kiểm duyệt trong 24 giờ.',
              color: _blue,
              bgColor: _blueLight,
            ),

          const SizedBox(height: 12),

          // Phone info
          _Card(child: Row(
            children: [
              const Icon(Icons.phone_rounded, size: 16, color: _gray400),
              const SizedBox(width: 8),
              const Text('Số điện thoại: ', style: TextStyle(fontSize: 13, color: _gray600)),
              Text(_phone ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _gray900)),
            ],
          )),

          const SizedBox(height: 12),

          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],

          // Personal info
          _Card(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(icon: Icons.person_rounded, label: 'Thông tin cá nhân'),
                  const SizedBox(height: 14),
                  _FormField(label: 'Họ và tên *', controller: _fullNameCtrl, enabled: !_kycLocked,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ và tên' : null),
                  const SizedBox(height: 12),
                  _FormField(
                    label: 'Ngày sinh *', controller: _dobCtrl, enabled: !_kycLocked,
                    readOnly: true, onTap: _kycLocked ? null : _pickDob,
                    hint: 'yyyy-mm-dd',
                    suffix: const Icon(Icons.calendar_today_rounded, size: 16, color: _gray400),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Chọn ngày sinh' : null,
                  ),
                  const SizedBox(height: 12),
                  _FormField(label: 'Số CCCD *', controller: _citizenIdCtrl, enabled: !_kycLocked,
                      keyboardType: TextInputType.number,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập số CCCD' : null),
                  const SizedBox(height: 12),
                  _FormField(label: 'Địa chỉ *', controller: _addressCtrl, enabled: !_kycLocked,
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập địa chỉ' : null),
                  const SizedBox(height: 12),
                  _FormField(label: 'Nghề nghiệp *', controller: _occupationCtrl, enabled: !_kycLocked,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập nghề nghiệp' : null),
                  const SizedBox(height: 12),
                  _FormField(label: 'Thu nhập hàng tháng (VND) *', controller: _monthlyIncomeCtrl,
                      enabled: !_kycLocked, keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nhập thu nhập';
                        final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0) return 'Thu nhập không hợp lệ';
                        return null;
                      }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Document photos
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(icon: Icons.badge_rounded, label: 'Giấy tờ tuỳ thân'),
                const SizedBox(height: 14),
                _UploadField(
                  label: 'CCCD mặt trước',
                  imageUrl: _citizenFrontImageUrl,
                  uploading: _uploadingFront || _kycLocked,
                  onPick: () => _pickAndUpload(
                    onUploaded: (url) => setState(() => _citizenFrontImageUrl = url),
                    onUploading: (v) => setState(() => _uploadingFront = v),
                  ),
                ),
                const SizedBox(height: 12),
                _UploadField(
                  label: 'CCCD mặt sau',
                  imageUrl: _citizenBackImageUrl,
                  uploading: _uploadingBack || _kycLocked,
                  onPick: () => _pickAndUpload(
                    onUploaded: (url) => setState(() => _citizenBackImageUrl = url),
                    onUploading: (v) => setState(() => _uploadingBack = v),
                  ),
                ),
                const SizedBox(height: 12),
                _UploadField(
                  label: 'Ảnh chân dung (selfie)',
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

          const SizedBox(height: 12),

          // OTP
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(icon: Icons.sms_rounded, label: 'Xác thực OTP'),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _sendingOtp || _kycLocked ? null : _sendOtp,
                    icon: Icon(_sendingOtp ? Icons.hourglass_empty_rounded : Icons.send_rounded, size: 16),
                    label: Text(_sendingOtp ? 'Đang gửi OTP...' : 'Gửi mã OTP đến ${_phone ?? ''}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_devOtpHint != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(_devOtpHint!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontFamily: 'monospace')),
                  ),
                ],
                const SizedBox(height: 12),
                _FormField(
                  label: 'Mã OTP (6 số)',
                  controller: _otpCtrl,
                  enabled: !_kycLocked,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: _loading || _kycLocked ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gửi yêu cầu KYC',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _gray200),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: _blue),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _gray900)),
    ],
  );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hint;
  final Widget? suffix;

  const _FormField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.hint,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: _gray600, letterSpacing: 0.2)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          onTap: onTap,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: _gray900),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _gray400, fontSize: 13),
            suffixIcon: suffix,
            counterText: '',
            filled: true,
            fillColor: enabled ? const Color(0xFFF9FAFB) : _gray100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _gray200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _gray200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _blue, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _gray100)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444))),
          ),
        ),
      ],
    );
  }
}

class _UploadField extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;

  const _UploadField({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: _gray600, letterSpacing: 0.2)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: uploading ? null : onPick,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasImage ? null : _gray100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasImage ? _green.withValues(alpha: 0.4) : _gray200,
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: uploading
                ? const Center(child: CircularProgressIndicator())
                : hasImage
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.network(imageUrl!, fit: BoxFit.cover,
                                width: double.infinity, height: double.infinity),
                          ),
                          Positioned(top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.cloud_upload_outlined, size: 32, color: _gray400),
                          SizedBox(height: 6),
                          Text('Nhấn để chọn ảnh', style: TextStyle(fontSize: 13, color: _gray400)),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color bgColor;

  const _InfoBanner({required this.icon, required this.message, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: color, height: 1.5))),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
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
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), height: 1.4))),
      ],
    ),
  );
}