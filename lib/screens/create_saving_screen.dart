import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api/account_api.dart';
import '../api/authed_api.dart';
import '../api/profile_api.dart';
import '../api/saving_api.dart';
import '../auth/auth_storage.dart';
import '../config/app_config.dart';
import '../security/device_identity.dart';

// ?"??"??"? Design tokens ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
class _C {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAF0);
  static const primary = Color(0xFF0D1B3E);
  static const secondary = Color(0xFF6B7299);
  static const green = Color(0xFF1D9E75);
  static const greenDark = Color(0xFF085041);
  static const greenLight = Color(0xFFE1F5EE);
  static const blue = Color(0xFF2563EB);
  static const blueLight = Color(0xFFEFF6FF);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEF2F2);

  // Rate matrix tier colors (saving)
  static const s0Fill = Color(0xFFE1F5EE);
  static const s0Text = Color(0xFF085041);
  static const s1Fill = Color(0xFF9FE1CB);
  static const s1Text = Color(0xFF04342C);
  static const s2Fill = Color(0xFF1D9E75);
  static const s2TextW = Colors.white;
}

// ?"??"??"? Data models ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
class _MatrixRow {
  final String label;
  final double amount;
  const _MatrixRow(this.label, this.amount);
}

class _SavingSel {
  final int rowIdx;
  final int colIdx;
  final double amount;
  final int months;
  final double rate;
  const _SavingSel(
    this.rowIdx,
    this.colIdx,
    this.amount,
    this.months,
    this.rate,
  );
}

const _sRows = [
  _MatrixRow('< 10 trieu', 5_000_000),
  _MatrixRow('10 - 50 trieu', 30_000_000),
  _MatrixRow('50 - 100 trieu', 75_000_000),
  _MatrixRow('> 100 trieu', 200_000_000),
];
const _sCols = [1, 3, 6, 12, 24];
const _sRates = [
  [4.0, 4.3, 4.8, 5.5, 5.8],
  [4.2, 4.6, 5.2, 5.8, 6.1],
  [4.5, 4.9, 5.5, 6.2, 6.5],
  [4.8, 5.2, 5.8, 6.5, 6.8],
];

// ?"??"??"? Screen ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
class CreateSavingScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const CreateSavingScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<CreateSavingScreen> createState() => _CreateSavingScreenState();
}

class _CreateSavingScreenState extends State<CreateSavingScreen> {
  late AccountApi _accountApi;
  late ProfileApi _profileApi;
  late SavingApi _savingApi;
  final _picker = ImagePicker();

  // Step 0 = matrix; steps 1-4 = form pages
  int _step = 0;
  _SavingSel? _sel;

  // Pre-filled user info (from KYC / profile ??" replace with real fetch)
  final Map<String, String> _user = {
    'fullName': 'Nguyen Van An',
    'dob': '15/05/1990',
    'citizenId': '034190012345',
    'phone': '0912 345 678',
    'email': 'nguyenvanan@gmail.com',
    'address': '123 Duong Lang, Dong Da, Ha Noi',
  };

  // Form step 1 ??" product config
  String _interestMode = 'Cuoi ky';
  bool _autoRenew = false;
  final _noteCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // Form step 2 ??" accounts
  bool _loadingAccounts = false;
  String? _accountsError;
  List<AccountResolve> _accounts = const [];
  int? _srcAccountId;
  int? _settleAccountId;

  // Saving products (for real product IDs)
  bool _loadingProducts = false;
  String? _productsError;
  List<SavingProduct> _savingProducts = const [];
  int? _selectedSavingProductId;

  // Form step 3 ??" documents
  final Map<String, String?> _uploadedDocs = {};
  final Map<String, bool> _uploadingDocs = {};

  // Step 4 ??" agreement + OTP
  bool _agreementAccepted = false;
  bool _sendingOtp = false;
  bool _confirmingOtp = false;
  int? _openTxId;
  String? _devOtpHint;
  String? _openedSavingCode;
  final _otpCtrl = TextEditingController();

  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _accountApi = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _profileApi = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _savingApi = SavingApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _loadProfile();
    _loadAccounts();
    _loadProducts();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _amountCtrl.dispose();
    _otpCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ?"??"??"? Helpers ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  String _fmtMoney(double v) {
    if (v >= 1e9)
      return '${(v / 1e9).toStringAsFixed(1).replaceAll('.0', '')} ty';
    if (v >= 1e6) return '${(v / 1e6).round()} trieu';
    return v.toStringAsFixed(0);
  }

  String _fmtFull(double v) =>
      '${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} VND';

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileApi.me();
      if (!mounted) return;
      setState(() {
        _user['fullName'] = profile.fullName ?? _user['fullName']!;
        _user['dob'] = profile.dob ?? _user['dob']!;
        _user['phone'] = profile.phone ?? _user['phone']!;
        _user['email'] = profile.email ?? _user['email']!;
        _user['address'] = profile.address ?? _user['address']!;
      });
    } catch (_) {
      // Keep demo values if profile fetch fails.
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loadingAccounts = true;
      _accountsError = null;
    });
    try {
      final accounts = await _accountApi.myAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        if (accounts.isEmpty) {
          _srcAccountId = null;
          _settleAccountId = null;
          _accountsError = 'Ban chua co tai khoan de mo so tiet kiem.';
        } else {
          _srcAccountId ??= accounts.first.id;
          _settleAccountId ??= accounts.length > 1
              ? accounts[1].id
              : accounts.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsError = e.toString();
        _accounts = const [];
        _srcAccountId = null;
        _settleAccountId = null;
      });
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final products = await _savingApi.getSavingProducts();
      if (!mounted) return;
      setState(() => _savingProducts = products);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = e.toString();
        _savingProducts = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  double _toPercentRate(double raw) => raw <= 1 ? raw * 100 : raw;

  int _termMonthsOfProduct(SavingProduct p) {
    return p.termUnit.toUpperCase() == 'YEAR' ? p.termValue * 12 : p.termValue;
  }

  List<SavingProduct> _productsForSelection(_SavingSel s, double amount) {
    return _savingProducts.where((p) {
      final termMatches = _termMonthsOfProduct(p) == s.months;
      final minOk = p.minOpenAmount == null || amount >= p.minOpenAmount!;
      final maxOk = p.maxOpenAmount == null || amount <= p.maxOpenAmount!;
      final active = p.status.toLowerCase() == 'active';
      return termMatches && minOk && maxOk && active;
    }).toList();
  }

  SavingProduct? _selectedSavingProduct(_SavingSel s, double amount) {
    final candidates = _productsForSelection(s, amount);
    if (candidates.isEmpty) return null;
    if (_selectedSavingProductId != null) {
      for (final p in candidates) {
        if (p.id == _selectedSavingProductId) return p;
      }
    }
    return candidates.first;
  }

  AccountResolve? _accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  double? _enteredAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  ({double interest, double total, String maturity}) _calcSaving(
    _SavingSel s,
    double amount,
    double annualRatePercent,
  ) {
    final monthly = amount * (annualRatePercent / 100 / 12) * s.months;
    final total = amount + monthly;
    final mat = DateTime.now().add(Duration(days: s.months * 30));
    final matStr =
        '${mat.day.toString().padLeft(2, '0')}/${mat.month.toString().padLeft(2, '0')}/${mat.year}';
    return (interest: monthly, total: total, maturity: matStr);
  }

  ({Color fill, Color text}) _tierColor(double rate) {
    if (rate < 5) return (fill: _C.s0Fill, text: _C.s0Text);
    if (rate < 6) return (fill: _C.s1Fill, text: _C.s1Text);
    return (fill: _C.s2Fill, text: _C.s2TextW);
  }

  void _goStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  bool get _requiredDocsUploaded =>
      _uploadedDocs['cccd_front'] != null && _uploadedDocs['cccd_back'] != null;

  String _interestPostingMode() => switch (_interestMode) {
        'Hang thang' => 'MONTHLY',
        'Dau ky' => 'START_OF_TERM',
        _ => 'END_OF_TERM',
      };

  bool _ensureCloudinaryConfigured() {
    if (AppConfig.cloudinaryCloudName.isEmpty || AppConfig.cloudinaryUploadPreset.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua cau hinh Cloudinary.')),
      );
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
      ..fields['folder'] = 'minibank/saving-docs';
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'saving.jpg',
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }
    final res = await http.Response.fromStream(await request.send());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upload that bai: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final url = data['secure_url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Khong lay duoc URL anh');
    return url;
  }

  String _docTypeFor(String docId) => switch (docId) {
        'cccd_front' => 'saving_cccd_front',
        'cccd_back' => 'saving_cccd_back',
        'selfie' => 'saving_selfie',
        _ => 'saving_document',
      };

  Future<void> _pickAndUploadDoc(String docId) async {
    if (!_ensureCloudinaryConfigured()) return;
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingDocs[docId] = true);
    try {
      final url = await _uploadToCloudinary(file);
      if (!mounted) return;
      setState(() => _uploadedDocs[docId] = url);
      try {
        await _profileApi.uploadDocument(
          documentType: _docTypeFor(docId),
          fileUrl: url,
          fileName: file.name,
          mimeType: 'image/jpeg',
          note: 'saving_request',
        );
      } catch (_) {
        // Best effort: saving request still proceeds even if document record fails.
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi tai len: $e'), backgroundColor: _C.error),
      );
    } finally {
      if (mounted) setState(() => _uploadingDocs[docId] = false);
    }
  }

  void _resetOtpState() {
    _openTxId = null;
    _devOtpHint = null;
    _otpCtrl.clear();
    _openedSavingCode = null;
  }

  void _validateBeforeOtp() {
    final amount = _enteredAmount();
    if (_sel == null || amount == null) {
      throw Exception('Vui long chon ky han va nhap so tien gui');
    }
    if (_srcAccountId == null || _settleAccountId == null) {
      throw Exception('Vui long chon tai khoan nguon va tai khoan tat toan');
    }
    if (!_requiredDocsUploaded) {
      throw Exception('Vui long tai len 2 mat CCCD');
    }
    if (_loadingProducts) {
      throw Exception('Dang tai san pham tiet kiem, vui long thu lai');
    }
    if (_savingProducts.isEmpty) {
      throw Exception(_productsError ?? 'Chua tai duoc san pham tiet kiem');
    }
    final product = _selectedSavingProduct(_sel!, amount);
    if (product == null) {
      throw Exception('Chua co san pham tiet kiem phu hop cho ky han ${_sel!.months} thang va so tien da nhap');
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _sendingOtp = true);
    try {
      _validateBeforeOtp();
      if (!_agreementAccepted) {
        throw Exception('Vui long tich chon: da doc va chap nhan thoa thuan');
      }

      final amount = _enteredAmount()!;
      final product = _selectedSavingProduct(_sel!, amount)!;

      final res = await _savingApi.initiateOpenSaving(
        savingProductId: product.id,
        sourceAccountId: _srcAccountId!,
        settlementAccountId: _settleAccountId,
        principalAmount: amount.toStringAsFixed(0),
        autoRenew: _autoRenew,
        agreementAccepted: true,
        agreementVersion: 'saving_agreement_v1',
      );

      if (!mounted) return;
      setState(() {
        _openTxId = res.transactionId;
        _devOtpHint = res.debugOtp;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP da duoc gui. Vui long nhap OTP de gui yeu cau mo so.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi: $e'), backgroundColor: _C.error),
      );
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _confirmOpen() async {
    setState(() => _confirmingOtp = true);
    try {
      final txId = _openTxId;
      if (txId == null || txId <= 0) throw Exception('Vui long nhan OTP truoc');
      final otp = _otpCtrl.text.trim();
      if (otp.length != 6) throw Exception('OTP phai gom 6 chu so');

      final res = await _savingApi.confirmOpenSaving(
        transactionId: txId,
        otpCode: otp,
      );

      if (!mounted) return;
      setState(() => _openedSavingCode = res.savingCode);
      _goStep(5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi: $e'), backgroundColor: _C.error),
      );
    } finally {
      if (mounted) setState(() => _confirmingOtp = false);
    }
  }

  // ?"??"??"? Build ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: _C.primary,
          ),
          onPressed: () {
            if (_step == 0) {
              Navigator.of(context).pop();
              return;
            }
            _goStep(_step - 1);
          },
        ),
        title: Text(
          _step == 0 ? 'Mo so tiet kiem' : _stepTitle(_step),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _C.primary,
          ),
        ),
        bottom: _step > 0 && _step < 5
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _step / 4,
                  backgroundColor: _C.border,
                  color: _C.green,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildMatrix(),
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
          _buildSuccess(),
        ],
      ),
    );
  }

  String _stepTitle(int s) => switch (s) {
    1 => 'Thong tin ca nhan',
    2 => 'Tai khoan',
    3 => 'Tai lieu xac minh',
    4 => 'Xac nhan thong tin',
    _ => 'Hoan tat',
  };

  // ?"??"??"? Step 0: Rate matrix ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildMatrix() {
    final enteredAmount = _enteredAmount();
    final candidates = (_sel != null && enteredAmount != null)
        ? _productsForSelection(_sel!, enteredAmount)
        : const <SavingProduct>[];
    final selectedProduct = (_sel != null && enteredAmount != null)
        ? _selectedSavingProduct(_sel!, enteredAmount)
        : null;
    final canContinue = _sel != null && enteredAmount != null && selectedProduct != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chon ky han va nhap so tien gui de xem lai suat',
            style: TextStyle(fontSize: 13, color: _C.secondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Nhap so tien gui tiet kiem (VND)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(_C.s0Fill, '4-5%'),
              const SizedBox(width: 14),
              _legendDot(_C.s1Fill, '5-6%'),
              const SizedBox(width: 14),
              _legendDot(_C.s2Fill, '6%+'),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Dang tai san pham tiet kiem...', style: TextStyle(fontSize: 12, color: _C.secondary)),
            )
          else if (_savingProducts.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_productsError ?? 'Chua co san pham tiet kiem dang hoat dong.', style: const TextStyle(fontSize: 12, color: _C.error)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadProducts, child: const Text('Tai lai san pham')),
                ],
              ),
            ),
          _buildRateTable(),
          const SizedBox(height: 16),
          if (_sel != null && enteredAmount != null) ...[
            _sectionHeader(Icons.inventory_2_outlined, 'San pham tiet kiem dang hoat dong'),
            if (candidates.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.errorLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.error.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'Khong co san pham tiet kiem nao phu hop voi ky han va so tien da nhap.',
                  style: TextStyle(fontSize: 12, color: _C.error),
                ),
              )
            else
              Column(
                children: candidates.map((p) {
                  final isSelected = _selectedSavingProductId == p.id ||
                      (selectedProduct != null && _selectedSavingProductId == null && selectedProduct.id == p.id);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSavingProductId = p.id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _C.greenLight : _C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? _C.green : _C.border, width: isSelected ? 1.5 : 0.8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.primary)),
                                const SizedBox(height: 2),
                                Text('Ky han ${_termMonthsOfProduct(p)} thang - Tu ${_fmtFull(p.minOpenAmount ?? 0)}', style: const TextStyle(fontSize: 11, color: _C.secondary)),
                              ],
                            ),
                          ),
                          Text('${_toPercentRate(p.baseInterestRate).toStringAsFixed(2)}%/nam', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.greenDark)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
          ],
          if (_sel != null && enteredAmount != null) ...[
            _buildSelBanner(enteredAmount, selectedProduct),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: canContinue ? () => _goStep(1) : null,
                child: const Text('Tiep tuc mo so tiet kiem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else if (_sel != null) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Vui long nhap so tien gui de tinh lai va tiep tuc.', style: TextStyle(fontSize: 11, color: _C.error)),
            ),
          ],
        ],
      ),
    );
  }
  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: _C.secondary)),
    ],
  );

  Widget _buildRateTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: _C.border, width: 0.5),
        children: [
          // Header row
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F3F9)),
            children: [
              _thCell('So tien', isFirst: true),
              ..._sCols.map((m) => _thCell('${m}T')),
            ],
          ),
          // Data rows
          for (int ri = 0; ri < _sRows.length; ri++)
            TableRow(
              children: [
                _rowHeader(_sRows[ri].label),
                for (int ci = 0; ci < _sCols.length; ci++) _rateCell(ri, ci),
              ],
            ),
        ],
      ),
    );
  }

  Widget _thCell(String text, {bool isFirst = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _C.secondary,
      ),
      textAlign: isFirst ? TextAlign.left : TextAlign.center,
    ),
  );

  Widget _rowHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Text(text, style: const TextStyle(fontSize: 12, color: _C.primary)),
  );

  Widget _rateCell(int ri, int ci) {
    final rate = _sRates[ri][ci];
    final colors = _tierColor(rate);
    final isSelected = _sel?.rowIdx == ri && _sel?.colIdx == ci;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(
          () {
            _sel = _SavingSel(ri, ci, _sRows[ri].amount, _sCols[ci], rate);
            _selectedSavingProductId = null;
          },
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: colors.fill,
          border: isSelected ? Border.all(color: _C.greenDark, width: 2) : null,
        ),
        child: Text(
          '${rate.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? _C.greenDark : colors.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSelBanner(double amount, SavingProduct? selectedProduct) {
    final s = _sel!;
    final ratePercent = selectedProduct != null ? _toPercentRate(selectedProduct.baseInterestRate) : s.rate;
    final c = _calcSaving(s, amount, ratePercent);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.greenLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gui ${_fmtMoney(amount)} - ${s.months} thang',
            style: const TextStyle(fontSize: 12, color: _C.secondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statBox(
                  'Lai suat',
                  '${ratePercent.toStringAsFixed(2)}%/nam',
                  _C.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statBox('Tien lai', _fmtFull(c.interest), _C.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statBox('Nhan ve', _fmtFull(c.total), _C.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: _statBox('Dao han', c.maturity, _C.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _C.secondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    ),
  );

  // ?"??"??"? Step 1: Personal info ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoNote(
            'Thong tin duoc lay tu ho so KYC cua ban. Vui long kiem tra lai truoc khi tiep tuc.',
            icon: Icons.info_outline,
            color: _C.green,
            bgColor: _C.greenLight,
          ),
          const SizedBox(height: 4),
          _sectionHeader(Icons.person_outline, 'Thong tin ca nhan'),
          _prefilledField('Ho va ten', _user['fullName']!),
          Row(
            children: [
              Expanded(child: _prefilledField('Ngay sinh', _user['dob']!)),
              const SizedBox(width: 10),
              Expanded(child: _prefilledField('So CCCD', _user['citizenId']!)),
            ],
          ),
          _prefilledField('Dia chi thuong tru', _user['address']!),
          Row(
            children: [
              Expanded(
                child: _prefilledField('So dien thoai', _user['phone']!),
              ),
              const SizedBox(width: 10),
              Expanded(child: _prefilledField('Email', _user['email']!)),
            ],
          ),
          _sectionHeader(Icons.savings_outlined, 'Cai dat so tiet kiem'),
          _labelText('Hinh thuc linh lai', required: true),
          _radioGroup(
            options: ['Cuoi ky', 'Hang thang', 'Dau ky'],
            selected: _interestMode,
            onChanged: (v) => setState(() => _interestMode = v),
            accent: _C.green,
          ),
          const SizedBox(height: 12),
          _toggleTile(
            'Tu dong tai tuc khi dao han',
            'Dao han se tu dong mo so moi theo ky han hien tai',
            _autoRenew,
            (v) => setState(() => _autoRenew = v),
          ),
          const SizedBox(height: 12),
          _labelText('Ghi chu'),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Ghi chu them (khong bat buoc)'),
          ),
          const SizedBox(height: 24),
          _nextBtn('Tiep tuc', () => _goStep(2)),
        ],
      ),
    );
  }

  // ?"??"??"? Step 2: Accounts ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.account_balance_outlined,
            'Tai khoan nguon & tat toan',
          ),
          const Text(
            'Tai khoan trich tien gui se bi tam khoa so du trong suot ky han.',
            style: TextStyle(fontSize: 13, color: _C.secondary),
          ),
          const SizedBox(height: 14),
          if (_loadingAccounts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_accountsError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _accountsError!,
                    style: const TextStyle(fontSize: 12, color: _C.error),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadAccounts,
                    child: const Text('Tai lai tai khoan'),
                  ),
                ],
              ),
            )
          else ...[
            _labelText('Tai khoan trich tien gui', required: true),
            ..._accounts.map(
              (account) => _accountTile(
                account,
                account.id == _srcAccountId,
                () => setState(() => _srcAccountId = account.id),
                _C.green,
                _C.greenLight,
              ),
            ),
            const SizedBox(height: 16),
            _labelText('Tai khoan nhan tat toan', required: true),
            ..._accounts.map(
              (account) => _accountTile(
                account,
                account.id == _settleAccountId,
                () => setState(() => _settleAccountId = account.id),
                _C.green,
                _C.greenLight,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _infoNote(
            'Lai va goc se duoc chuyen ve tai khoan nay khi dao han.',
            icon: Icons.lock_outline,
            color: _C.green,
            bgColor: _C.greenLight,
          ),
          const SizedBox(height: 24),
          _nextBtn(
            'Tiep tuc',
            () => _goStep(3),
            disabled:
                _loadingAccounts ||
                _accounts.isEmpty ||
                _srcAccountId == null ||
                _settleAccountId == null,
          ),
        ],
      ),
    );
  }

  // ?"??"??"? Step 3: Documents ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildStep3() {
    final frontDone = _uploadedDocs['cccd_front'] != null;
    final backDone = _uploadedDocs['cccd_back'] != null;
    final selfieDone = _uploadedDocs['selfie'] != null;
    final frontUploading = _uploadingDocs['cccd_front'] == true;
    final backUploading = _uploadingDocs['cccd_back'] == true;
    final selfieUploading = _uploadingDocs['selfie'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoNote(
            'Tai anh ro net, khong bi mo hoac che khuat thong tin. Dinh dang JPG/PNG.',
            icon: Icons.info_outline,
            color: _C.green,
            bgColor: _C.greenLight,
          ),
          _sectionHeader(Icons.badge_outlined, 'Giay to tuy than'),
          _uploadTile(
            'Anh CCCD mat truoc',
            'JPG/PNG toi da 5MB',
            true,
            frontDone,
            frontUploading,
            () => _pickAndUploadDoc('cccd_front'),
            _C.green,
            _C.greenLight,
          ),
          const SizedBox(height: 8),
          _uploadTile(
            'Anh CCCD mat sau',
            'JPG/PNG toi da 5MB',
            true,
            backDone,
            backUploading,
            () => _pickAndUploadDoc('cccd_back'),
            _C.green,
            _C.greenLight,
          ),
          const SizedBox(height: 8),
          _uploadTile(
            'Anh chan dung cam CCCD',
            'JPG/PNG chup ro net',
            false,
            selfieDone,
            selfieUploading,
            () => _pickAndUploadDoc('selfie'),
            _C.green,
            _C.greenLight,
          ),
          const SizedBox(height: 24),
          _nextBtn(
            'Tiep tuc',
            () => _goStep(4),
            disabled: !_requiredDocsUploaded,
          ),
          if (!_requiredDocsUploaded)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '* Vui long tai len 2 mat CCCD truoc khi tiep tuc',
                style: TextStyle(fontSize: 11, color: _C.error),
              ),
            ),
        ],
      ),
    );
  }

  // ?"??"??"? Step 4: Confirm ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildStep4() {
    final amount = _enteredAmount();
    if (_sel == null || amount == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 20),
            Text(
              'Vui long chon ky han va nhap so tien gui o buoc dau tien.',
              style: TextStyle(fontSize: 14, color: _C.secondary),
            ),
          ],
        ),
      );
    }
    final s = _sel!;
    final product = _selectedSavingProduct(s, amount);
    final ratePercent = product != null ? _toPercentRate(product.baseInterestRate) : s.rate;
    final c = _calcSaving(s, amount, ratePercent);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.check_circle_outline, 'Xac nhan thong tin'),
          _confirmCard('Thong tin so tiet kiem', [
            ('San pham', product != null ? '${product.name} (${product.code})' : 'Tiet kiem ky han'),
            ('So tien gui', _fmtFull(amount)),
            ('Ky han', '${s.months} thang'),
            ('Lai suat', '${ratePercent.toStringAsFixed(2)}%/nam'),
            ('Tien lai du kien', _fmtFull(c.interest)),
            ('Nhan ve khi dao han', _fmtFull(c.total)),
            ('Ngay dao han', c.maturity),
            ('Linh lai', _interestMode),
            ('Tu dong tai tuc', _autoRenew ? 'Co' : 'Khong'),
          ]),
          const SizedBox(height: 12),
          _confirmCard('Thong tin ca nhan', [
            ('Ho va ten', _user['fullName']!),
            ('So CCCD', _user['citizenId']!),
            ('So dien thoai', _user['phone']!),
          ]),
          const SizedBox(height: 12),
          _confirmCard('Tai khoan', [
            ('Trich tien', _accountById(_srcAccountId)?.accountNumber ?? '-'),
            ('Tat toan', _accountById(_settleAccountId)?.accountNumber ?? '-'),
          ]),
          const SizedBox(height: 12),
          _infoNote(
            'Truoc khi nhan OTP, ban can xac nhan da doc va chap nhan thoa thuan mo so.',
            icon: Icons.security_outlined,
            color: _C.blue,
            bgColor: _C.blueLight,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: CheckboxListTile(
              value: _agreementAccepted,
              onChanged: (v) {
                setState(() {
                  _agreementAccepted = v ?? false;
                  if (!_agreementAccepted) {
                    _resetOtpState();
                  }
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Toi da doc va chap nhan thoa thuan mo so tiet kiem',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary),
              ),
              subtitle: const Text(
                'Tich chon de tiep tuc nhan OTP va hoan tat giao dich mo so.',
                style: TextStyle(fontSize: 12, color: _C.secondary, height: 1.35),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
          const SizedBox(height: 12),
          if (_openTxId == null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (_sendingOtp || !_agreementAccepted) ? null : _sendOtp,
                child: _sendingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Nhan OTP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ] else ...[
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: _inputDeco('Nhap OTP').copyWith(counterText: ''),
            ),
            if (_devOtpHint != null && _devOtpHint!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Dev OTP: $_devOtpHint',
                  style: const TextStyle(fontSize: 12, color: _C.secondary),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirmingOtp ? null : _confirmOpen,
                child: _confirmingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Xac nhan mo so',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ?"??"??"? Step 5: Success ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _C.greenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 44,
                color: _C.green,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Yeu cau mo so da duoc gui!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _openedSavingCode != null && _openedSavingCode!.isNotEmpty
                  ? 'So so: $_openedSavingCode\nTien da duoc trich tu tai khoan nguon va ho so dang cho admin duyet.'
                  : 'Tien da duoc trich tu tai khoan nguon va ho so dang cho admin duyet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _C.secondary, height: 1.6),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _C.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Ve trang chinh',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ?"??"??"? Shared widgets ?"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"??"?
  Widget _sectionHeader(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _C.secondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _C.secondary,
          ),
        ),
      ],
    ),
  );

  Widget _labelText(String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _C.secondary)),
        if (required)
          const Text(' *', style: TextStyle(fontSize: 12, color: _C.error)),
      ],
    ),
  );

  Widget _prefilledField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: _C.secondary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _C.greenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check, size: 10, color: _C.green),
                  SizedBox(width: 2),
                  Text(
                    'Da co',
                    style: TextStyle(fontSize: 10, color: _C.green),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: _C.secondary),
          ),
        ),
      ],
    ),
  );

  Widget _radioGroup({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required Color accent,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((opt) {
      final isSelected = opt == selected;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(opt);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _C.greenLight : _C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? accent : _C.border,
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Text(
            opt,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? _C.greenDark : _C.primary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _toggleTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border),
    ),
    child: SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: _C.secondary),
      ),
      value: value,
      activeColor: _C.green,
      onChanged: onChanged,
    ),
  );

  Widget _accountTile(
    AccountResolve account,
    bool selected,
    VoidCallback onTap,
    Color accent,
    Color accentLight,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? accentLight : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : _C.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 20,
              color: selected ? accent : _C.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${account.accountNumber} - ${account.accountName}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? _C.primary : _C.secondary,
                ),
              ),
            ),
            Text(
              'ID ${account.id}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? accent : _C.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadTile(
    String title,
    String subtitle,
    bool required,
    bool done,
    bool uploading,
    VoidCallback onTap,
    Color accent,
    Color accentLight,
  ) => GestureDetector(
    onTap: uploading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? accentLight : _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? accent : _C.border,
          width: done ? 1.5 : 0.5,
          style: done ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          uploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _C.green),
                )
              : Icon(
                  done ? Icons.check_circle : Icons.upload_file_outlined,
                  size: 22,
                  color: done ? accent : _C.secondary,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: done ? _C.primary : _C.primary,
                  ),
                ),
                Text(
                  done ? 'Da xac nhan, nhan de thay doi' : subtitle,
                  style: const TextStyle(fontSize: 11, color: _C.secondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: required ? _C.errorLight : const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              required ? 'Bat buoc' : 'Tuy chon',
              style: TextStyle(
                fontSize: 10,
                color: required ? _C.error : _C.secondary,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _confirmCard(String title, List<(String, String)> rows) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.border),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.secondary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _C.border),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.$1,
                  style: const TextStyle(fontSize: 12, color: _C.secondary),
                ),
                const Spacer(),
                Text(
                  r.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoNote(
    String text, {
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _nextBtn(String label, VoidCallback onTap, {bool disabled = false}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: disabled ? Colors.grey.shade300 : _C.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: disabled ? null : onTap,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: disabled ? _C.secondary : Colors.white,
            ),
          ),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _C.secondary),
    filled: true,
    fillColor: _C.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _C.border, width: 0.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _C.border, width: 0.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _C.green, width: 1.5),
    ),
  );
}










