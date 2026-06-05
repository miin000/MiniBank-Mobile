import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/account_api.dart';
import '../api/authed_api.dart';
import '../api/contract_api.dart';
import '../api/loan_api.dart';
import '../api/profile_api.dart';
import '../auth/auth_storage.dart';
import '../config/app_config.dart';
import '../security/device_identity.dart';

// Design tokens
class _C {
  static const bg          = Color(0xFFF7F8FC);
  static const surface     = Colors.white;
  static const border      = Color(0xFFE8EAF0);
  static const primary     = Color(0xFF0D1B3E);
  static const secondary   = Color(0xFF6B7299);
  static const blue        = Color(0xFF185FA5);
  static const blueDark    = Color(0xFF0C447C);
  static const blueLight   = Color(0xFFE6F1FB);
  static const blueMid     = Color(0xFF378ADD);
  static const green       = Color(0xFF1D9E75);
  static const greenLight  = Color(0xFFE1F5EE);
  static const error       = Color(0xFFEF4444);
  static const errorLight  = Color(0xFFFEF2F2);
  static const amber       = Color(0xFFBA7517);
  static const amberLight  = Color(0xFFFAEEDA);

  // Rate matrix tiers (loan - blue ramp)
  static const l0Fill = Color(0xFFE6F1FB);
  static const l0Text = Color(0xFF0C447C);
  static const l1Fill = Color(0xFFB5D4F4);
  static const l1Text = Color(0xFF042C53);
  static const l2Fill = Color(0xFF378ADD);
  static const l2TextW = Colors.white;
}

// Data models
class _MatrixRow {
  final String label;
  final double amount;
  const _MatrixRow(this.label, this.amount);
}

class _LoanSel {
  final int rowIdx, colIdx;
  final double amount;
  final int months;
  final double rate;
  const _LoanSel(this.rowIdx, this.colIdx, this.amount, this.months, this.rate);
}

const _lRows = [
  _MatrixRow('< 50 triệu',      30_000_000),
  _MatrixRow('50 - 200 triệu',  100_000_000),
  _MatrixRow('200 - 500 triệu', 350_000_000),
  _MatrixRow('> 500 triệu',     1_000_000_000),
];
const _lCols = [6, 12, 24, 36, 60];
const _lRates = [
  [8.5,  9.0,  9.5, 10.0, 10.5],
  [9.0,  9.5, 10.5, 11.0, 11.5],
  [9.5, 10.5, 11.5, 12.0, 12.5],
  [10.0,11.0, 12.0, 13.0, 14.0],
];

// Document descriptor
class _DocField {
  final String id;
  final String title;
  final String subtitle;
  final bool required;
  _DocField(this.id, this.title, this.subtitle, {this.required = true});
}

// Screen
class CreateLoanScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const CreateLoanScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  late LoanApi _loanApi;
  late ContractApi _contractApi;
  late ProfileApi _profileApi;
  late AccountApi _accountApi;

  // Step 0 = matrix; 1-4 = form; 5 = success
  int _step = 0;
  _LoanSel? _sel;

  // Pre-filled user info (replace with real fetch from profile service)
  final Map<String, String> _user = {
    'fullName'  : 'Nguyễn Văn An',
    'dob'       : '15/05/1990',
    'citizenId' : '034190012345',
    'phone'     : '0912 345 678',
    'email'     : 'nguyenvanan@gmail.com',
    'address'   : '123 Đường Láng, Đống Đa, Hà Nội',
  };

  // ?? Step 1: Personal / family info ??
  String _maritalStatus  = '';
  String _education      = '';
  final _dependentsCtrl  = TextEditingController(text: '0');
  final _mailAddrCtrl    = TextEditingController();

  // ?? Step 2: Employment / loan config ??
  String _occupation     = '';
  String _workDuration   = '';
  String _housingStatus  = '';
  final _amountCtrl      = TextEditingController();
  final _companyCtrl     = TextEditingController();
  final _incomeCtrl      = TextEditingController();
  final _otherIncomeCtrl = TextEditingController();
  final _purposeCtrl     = TextEditingController();
  final _collDescCtrl    = TextEditingController();
  final _collValCtrl     = TextEditingController();
  String _loanType       = 'unsecured'; // unsecured | secured
  bool _loadingAccounts  = false;
  String? _accountsError;
  List<AccountResolve> _accounts = const [];
  int? _disbAccountId;
  int? _repayAccountId;

  bool _loadingLoanProducts = false;
  String? _loanProductsError;
  List<LoanProduct> _loanProducts = const [];
  int? _selectedLoanProductId;

  // ?? Step 3: Documents ??
  // Map<docId, url|null>
  final Map<String, String?> _uploadedDocs = {};
  final Map<String, bool> _uploading       = {};

  bool _submitting = false;
  bool _agreementAccepted = false;
  bool _sendingOtp = false;
  ContractTemplateSummary? _contractTemplate;
  String? _contractTemplateCode;
  String? _contractError;
  String? _devOtpHint;
  final _otpCtrl = TextEditingController();
  final _pageCtrl  = PageController();

  // ??? Document list builders ??????????????????????????????????????????????
  List<_DocField> get _docs {
    return [
      // Identity - always required
      _DocField('cccd_front',  'Ảnh CCCD mặt trước',   'JPG/PNG, tối đa 5MB'),
      _DocField('cccd_back',   'Ảnh CCCD mặt sau',     'JPG/PNG, tối đa 5MB'),
      // Income proof - always required
      _DocField('payslip',     'Sao kê lương / bảng lương 3 tháng gần nhất',
               'PDF hoặc JPG/PNG'),
      _DocField('bank_stmt',   'Sao kê ngân hàng 6 tháng gần nhất',
               'PDF từ ngân hàng', required: false),
      // Secured-only
      if (_loanType == 'secured') ...[
        _DocField('coll_title','Giấy tờ tài sản thế chấp',
                   'Sổ đỏ / đăng ký xe / hợp đồng mua bán'),
        _DocField('coll_photo','Ảnh thực tế tài sản thế chấp',
                   'JPG/PNG, chụp rõ nét', required: false),
      ],
      // Unsecured optional support docs
      if (_loanType == 'unsecured')
        _DocField('work_cert', 'Xác nhận công tác / Hợp đồng lao động',
                   'Tăng tỷ lệ phê duyệt', required: false),
    ];
  }

  bool get _allRequiredDocsUploaded =>
      _docs.where((d) => d.required).every((d) => _uploadedDocs[d.id] != null);

  // ??? Lifecycle ???????????????????????????????????????????????????????????
  @override
  void initState() {
    super.initState();
    _loanApi = LoanApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _contractApi = ContractApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
    _profileApi = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _accountApi = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loadProfile();
    _loadAccounts();
    _loadLoanProducts();
  }

  @override
  void dispose() {
    _dependentsCtrl.dispose(); _mailAddrCtrl.dispose();
    _amountCtrl.dispose();
    _companyCtrl.dispose(); _incomeCtrl.dispose(); _otherIncomeCtrl.dispose();
    _purposeCtrl.dispose(); _collDescCtrl.dispose(); _collValCtrl.dispose();
    _otpCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ??? Helpers ?????????????????????????????????????????????????????????????
  String _fmtMoney(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1).replaceAll('.0', '')} tỷ';
    if (v >= 1e6) return '${(v / 1e6).round()} triệu';
    return v.round().toString();
  }

  String _fmtFull(double v) =>
      '${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} ₫';

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileApi.me();
      if (!mounted) return;
      setState(() {
        _user['fullName'] = profile.fullName ?? _user['fullName']!;
        _user['dob']      = profile.dob ?? _user['dob']!;
        _user['phone']    = profile.phone ?? _user['phone']!;
        _user['email']    = profile.email ?? _user['email']!;
        _user['address']  = profile.address ?? _user['address']!;
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
          _disbAccountId = null;
          _repayAccountId = null;
          _accountsError = 'Bạn chưa có tài khoản để đăng ký vay.';
        } else {
          _disbAccountId ??= accounts.first.id;
          _repayAccountId ??= accounts.length > 1 ? accounts[1].id : accounts.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accountsError = e.toString();
        _accounts = const [];
        _disbAccountId = null;
        _repayAccountId = null;
      });
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  AccountResolve? _accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<void> _loadLoanProducts() async {
    setState(() {
      _loadingLoanProducts = true;
      _loanProductsError = null;
    });
    try {
      final products = await _loanApi.getLoanProducts();
      if (!mounted) return;
      setState(() => _loanProducts = products);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loanProductsError = e.toString();
        _loanProducts = const [];
      });
    } finally {
      if (mounted) setState(() => _loadingLoanProducts = false);
    }
  }

  String _loanContractTemplateCode() =>
      _loanType == 'secured' ? 'LOAN_MORTGAGE' : 'LOAN_CREDIT';

  Future<void> _loadContractTemplate() async {
    final code = _loanContractTemplateCode();
    if (_contractTemplateCode == code && _contractTemplate != null) return;
    setState(() {
      _contractTemplateCode = code;
      _contractTemplate = null;
      _contractError = null;
      _agreementAccepted = false;
      _devOtpHint = null;
      _otpCtrl.clear();
    });
    try {
      ContractTemplateSummary tpl;
      try {
        tpl = await _contractApi.getActiveTemplateByCode(code);
      } catch (_) {
        final legacyCode = _loanType == 'secured'
            ? 'SECURED_LOAN_CONTRACT'
            : 'UNSECURED_LOAN_CONTRACT';
        tpl = await _contractApi.getActiveTemplateByCode(legacyCode);
      }
      if (!mounted) return;
      setState(() => _contractTemplate = tpl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _contractError = e.toString());
    }
  }

  double _toPercentRate(double raw) => raw <= 1 ? raw * 100 : raw;

  List<LoanProduct> _matchingLoanProducts(double amount, int termMonths) {
    if (_loanProducts.isEmpty) return const [];
    final desiredType = _loanType == 'secured' ? 'MORTGAGE' : 'PERSONAL';
    return _loanProducts.where((p) {
      final withinAmount = amount >= p.minAmount && amount <= p.maxAmount;
      final withinTerm = termMonths >= p.minTermMonths && termMonths <= p.maxTermMonths;
      final typeOk = p.loanType.toUpperCase() == desiredType;
      final active = p.status.toLowerCase() == 'active';
      return withinAmount && withinTerm && typeOk && active;
    }).toList();
  }

  LoanProduct? _selectedLoanProduct(double amount, int termMonths) {
    final matches = _matchingLoanProducts(amount, termMonths);
    if (matches.isEmpty) return null;
    if (_selectedLoanProductId != null) {
      for (final p in matches) {
        if (p.id == _selectedLoanProductId) return p;
      }
    }
    return matches.first;
  }

  double? _enteredAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  ({double monthly, double totalInterest, double total}) _calcLoan(_LoanSel s, double amount, double annualRatePercent) {
    final mr      = annualRatePercent / 100 / 12;
    final monthly = amount * mr * _pow(1 + mr, s.months) / (_pow(1 + mr, s.months) - 1);
    final total   = monthly * s.months;
    return (monthly: monthly, totalInterest: total - amount, total: total);
  }

  double _pow(double base, int exp) {
    var result = 1.0;
    for (var i = 0; i < exp; i++) result *= base;
    return result;
  }

  ({Color fill, Color text}) _tierColor(double rate) {
    if (rate < 10) return (fill: _C.l0Fill, text: _C.l0Text);
    if (rate < 12) return (fill: _C.l1Fill, text: _C.l1Text);
    return (fill: _C.l2Fill, text: _C.l2TextW);
  }

  List<String> _allowedExtensionsForDoc(String docId) {
    switch (docId) {
      case 'cccd_front':
      case 'cccd_back':
      case 'coll_photo':
        return ['jpg', 'jpeg', 'png'];
      case 'bank_stmt':
        return ['pdf'];
      default:
        return ['pdf', 'jpg', 'jpeg', 'png'];
    }
  }

  Future<PlatformFile?> _pickFileForDoc(String docId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensionsForDoc(docId),
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  void _goStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  // ??? Upload ??????????????????????????????????????????????????????????????
  Future<void> _pickAndUpload(String docId) async {
    if (AppConfig.cloudinaryCloudName.isEmpty || AppConfig.cloudinaryUploadPreset.isEmpty) {
      // Demo: simulate upload
      setState(() { _uploading[docId] = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() { _uploadedDocs[docId] = 'https://demo.url/$docId.jpg'; _uploading[docId] = false; });
      return;
    }
    final picked = await _pickFileForDoc(docId);
    if (picked == null) return;
    setState(() { _uploading[docId] = true; });
    try {
      final cloudName = AppConfig.cloudinaryCloudName;
      final preset    = AppConfig.cloudinaryUploadPreset;
      final uri       = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      final request   = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = preset
        ..fields['folder']        = 'minibank/loan-docs';
      if (picked.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          picked.bytes!,
          filename: picked.name.isNotEmpty ? picked.name : '$docId',
        ));
      } else if (picked.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          picked.path!,
          filename: picked.name.isNotEmpty ? picked.name : '$docId',
        ));
      } else {
        throw Exception('Không đọc được file');
      }
      final res  = await http.Response.fromStream(await request.send());
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final url  = data['secure_url']?.toString() ?? '';
      if (!mounted) return;
      setState(() { _uploadedDocs[docId] = url.isNotEmpty ? url : null; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải lên: $e'), backgroundColor: _C.error));
    } finally {
      if (mounted) setState(() { _uploading[docId] = false; });
    }
  }

  // ??? Submit ??????????????????????????????????????????????????????????????
  Future<void> _sendContractOtp() async {
    setState(() => _sendingOtp = true);
    try {
      if (!_agreementAccepted) {
        throw Exception('Vui lòng tích chọn đã đọc và chấp nhận hợp đồng');
      }
      if (_contractTemplate == null) {
        throw Exception(_contractError ?? 'Chưa tải được hợp đồng active');
      }
      final res = await _contractApi.sendContractOtp();
      if (!mounted) return;
      setState(() {
        _devOtpHint = res.otp;
        if (res.devMode && res.otp != null && res.otp!.isNotEmpty) {
          _otpCtrl.text = res.otp!;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP ký hợp đồng đã được gửi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: _C.error));
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final amount = _enteredAmount();
      if (_sel == null || amount == null) {
        throw Exception('Vui lòng chọn kỳ hạn và nhập số tiền vay');
      }
      if (_disbAccountId == null || _repayAccountId == null) {
        throw Exception('Vui lòng chọn tài khoản giải ngân và hoàn trả');
      }
      if (_loadingLoanProducts) {
        throw Exception('Đang tải sản phẩm vay, vui lòng thử lại');
      }
      if (_loanProducts.isEmpty) {
        throw Exception(_loanProductsError ?? 'Chưa có sản phẩm vay');
      }
      final product = _selectedLoanProduct(amount, _sel!.months);
      if (product == null) {
        throw Exception('Không tìm thấy sản phẩm vay phù hợp với số tiền/kỳ hạn đã chọn');
      }
      final deps = int.tryParse(_dependentsCtrl.text.trim());
      final collateralValue = double.tryParse(_collValCtrl.text.trim().replaceAll(RegExp(r'[^\d.]'), ''));
      await _loanApi.applyForLoan(
      loanProductId         : product.id,
      disbursementAccountId : _disbAccountId!,
      repaymentAccountId    : _repayAccountId!,
      amount                : amount.toStringAsFixed(0),
      termMonths            : _sel!.months,
      purpose               : _purposeCtrl.text.trim(),
      loanType              : _loanType,
      monthlyIncome         : _incomeCtrl.text.trim().isNotEmpty ? _incomeCtrl.text.trim() : null,
      collateralDescription : _loanType == 'secured' ? _collDescCtrl.text.trim() : null,
      collateralEstimatedValue: _loanType == 'secured' ? collateralValue : null,
      incomeProofUrl        : _uploadedDocs['payslip'],
      collateralProofUrl    : _uploadedDocs['coll_title'],
      bankStatementUrl      : _uploadedDocs['bank_stmt'],
      workCertUrl           : _uploadedDocs['work_cert'],
      maritalStatus         : _maritalStatus.isNotEmpty ? _maritalStatus : null,
      numberOfDependents    : deps,
      education             : _education.isNotEmpty ? _education : null,
      occupation            : _occupation.isNotEmpty ? _occupation : null,
      workDuration          : _workDuration.isNotEmpty ? _workDuration : null,
      housingStatus         : _housingStatus.isNotEmpty ? _housingStatus : null,
      mailingAddress        : _mailAddrCtrl.text.trim().isNotEmpty ? _mailAddrCtrl.text.trim() : null,
    );

    if (!mounted) return;
    _goStep(5);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: _C.error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _C.primary),
          onPressed: () {
            if (_step == 0) { Navigator.of(context).pop(); return; }
            _goStep(_step - 1);
          },
        ),
        title: Text(
          _step == 0 ? 'Đăng ký vay vốn' : _stepTitle(_step),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.primary),
        ),
        bottom: _step > 0 && _step < 5
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _step / 4,
                  backgroundColor: _C.border,
                  color: _C.blue,
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
    1 => 'Thông tin cá nhân',
    2 => 'Nghề nghiệp & khoản vay',
    3 => 'Tài liệu xác minh',
    4 => 'Xác nhận hồ sơ',
    _ => 'Hoàn tất',
  };

  // ??? Step 0: Rate matrix ??????????????????????????????????????????????????
  Widget _buildMatrix() {
    final enteredAmount = _enteredAmount();
    final candidates = (_sel != null && enteredAmount != null)
        ? _matchingLoanProducts(enteredAmount, _sel!.months)
        : const <LoanProduct>[];
    final selectedProduct = (_sel != null && enteredAmount != null)
        ? _selectedLoanProduct(enteredAmount, _sel!.months)
        : null;
    final canContinue = _sel != null && enteredAmount != null && selectedProduct != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(Icons.category_outlined, 'Loại vay'),
        _radioGroup(
          options: ['Tín chấp', 'Thế chấp'],
          selected: _loanType == 'unsecured' ? 'Tín chấp' : 'Thế chấp',
          onChanged: (v) => setState(() {
            _loanType = v == 'Tín chấp' ? 'unsecured' : 'secured';
            _sel = null;
            _selectedLoanProductId = null;
            _contractTemplateCode = null;
            _contractTemplate = null;
            _contractError = null;
            _agreementAccepted = false;
            _devOtpHint = null;
            _otpCtrl.clear();
          }),
        ),
        const SizedBox(height: 16),
        const Text('Chọn kỳ hạn và nhập số tiền vay để xem lãi suất',
            style: TextStyle(fontSize: 13, color: _C.secondary)),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('Nhập số tiền vay (VND)'),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _legendDot(_C.l0Fill, '8-10%'),
          const SizedBox(width: 14),
          _legendDot(_C.l1Fill, '10-12%'),
          const SizedBox(width: 14),
          _legendDot(_C.l2Fill, '12%+'),
        ]),
        const SizedBox(height: 10),
        _buildRateTable(),
        const SizedBox(height: 16),
        if (_sel != null && enteredAmount != null) ...[
          _sectionHeader(Icons.inventory_2_outlined, 'Sản phẩm vay đang hoạt động'),
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
                'Không có sản phẩm vay nào phù hợp với số tiền và kỳ hạn đã chọn.',
                style: TextStyle(fontSize: 12, color: _C.error),
              ),
            )
          else
            Column(
              children: candidates.map((p) {
                final isSelected = _selectedLoanProductId == p.id ||
                    (selectedProduct != null && _selectedLoanProductId == null && selectedProduct.id == p.id);
                return GestureDetector(
                  onTap: () => setState(() => _selectedLoanProductId = p.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? _C.blueLight : _C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? _C.blue : _C.border, width: isSelected ? 1.5 : 0.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.name} (${p.code})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.primary)),
                              const SizedBox(height: 2),
                              Text('${p.loanType} · ${p.minTermMonths}-${p.maxTermMonths} tháng', style: const TextStyle(fontSize: 11, color: _C.secondary)),
                            ],
                          ),
                        ),
                        Text('${_toPercentRate(p.baseInterestRate).toStringAsFixed(2)}%/năm', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.blueDark)),
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
                backgroundColor: _C.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: canContinue ? () => _goStep(1) : null,
                child: const Text('Tiếp tục đăng ký vay vốn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ] else if (_sel != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Vui lòng nhập số tiền vay để tính lãi và tiếp tục.',
                style: TextStyle(fontSize: 11, color: _C.error)),
          ),
        ],
      ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: _C.secondary)),
  ]);

  Widget _buildRateTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: _C.border, width: 0.5),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF1F3F9)),
            children: [
              _thCell('Số tiền', isFirst: true),
              ..._lCols.map((m) => _thCell('${m}T')),
            ],
          ),
          for (int ri = 0; ri < _lRows.length; ri++)
            TableRow(children: [
              _rowHeader(_lRows[ri].label),
              for (int ci = 0; ci < _lCols.length; ci++)
                _rateCell(ri, ci),
            ]),
        ],
      ),
    );
  }

  Widget _thCell(String text, {bool isFirst = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.secondary),
        textAlign: isFirst ? TextAlign.left : TextAlign.center),
  );

  Widget _rowHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Text(text, style: const TextStyle(fontSize: 12, color: _C.primary)),
  );

  Widget _rateCell(int ri, int ci) {
    final rate      = _lRates[ri][ci];
    final colors    = _tierColor(rate);
    final isSelected = _sel?.rowIdx == ri && _sel?.colIdx == ci;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _sel = _LoanSel(ri, ci, _lRows[ri].amount, _lCols[ci], rate);
          _selectedLoanProductId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: colors.fill,
          border: isSelected ? Border.all(color: _C.blueDark, width: 2) : null,
        ),
        child: Text('${rate.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: isSelected ? _C.blueDark : colors.text,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSelBanner(double amount, LoanProduct? selectedProduct) {
    final s = _sel!;
    final ratePercent = selectedProduct != null ? _toPercentRate(selectedProduct.baseInterestRate) : s.rate;
    final c = _calcLoan(s, amount, ratePercent);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.blueLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.blue.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vay ${_fmtMoney(amount)} · ${s.months} tháng',
            style: const TextStyle(fontSize: 12, color: _C.secondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statBox('Lãi suất/năm', '${ratePercent.toStringAsFixed(2)}%', _C.blue)),
          const SizedBox(width: 8),
          Expanded(child: _statBox('Trả hàng tháng', _fmtFull(c.monthly), _C.blue)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _statBox('Tổng lãi', _fmtFull(c.totalInterest), _C.primary)),
          const SizedBox(width: 8),
          Expanded(child: _statBox('Tổng phải trả', _fmtFull(c.total), _C.primary)),
        ]),
      ]),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _C.secondary)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
    ]),
  );

  // ??? Step 1: Personal / family info ??????????????????????????????????????
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoNote('Thông tin lấy từ hồ sơ KYC. Vui lòng bổ sung thêm thông tin gia đình.',
            icon: Icons.info_outline, color: _C.blue, bg: _C.blueLight),

        _sectionHeader(Icons.person_outline, 'Thông tin cơ bản'),
        _prefilledField('Họ và tên',       _user['fullName']!),
        Row(children: [
          Expanded(child: _prefilledField('Ngày sinh',   _user['dob']!)),
          const SizedBox(width: 10),
          Expanded(child: _prefilledField('Số CCCD',     _user['citizenId']!)),
        ]),
        _prefilledField('Địa chỉ thường trú', _user['address']!),
        Row(children: [
          Expanded(child: _prefilledField('Số điện thoại', _user['phone']!)),
          const SizedBox(width: 10),
          Expanded(child: _prefilledField('Email',          _user['email']!)),
        ]),

        _sectionHeader(Icons.people_outline, 'Thông tin gia đình'),
        _labelText('Tình trạng hôn nhân', required: true),
        _radioGroup(
          options : ['Độc thân', 'Đã kết hôn', 'Ly hôn', 'Góa'],
          selected: _maritalStatus,
          onChanged: (v) => setState(() => _maritalStatus = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Số người phụ thuộc'),
            TextField(
              controller: _dependentsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDeco('0'),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Trình độ học vấn'),
            _dropdownField(
              value: _education.isEmpty ? null : _education,
              hint: 'Chọn',
              items: ['THPT', 'Cao đẳng', 'Đại học', 'Sau đại học', 'Khác'],
              onChanged: (v) => setState(() => _education = v ?? ''),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        _labelText('Địa chỉ thư tín (nếu khác thường trú)'),
        TextField(
          controller: _mailAddrCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('Nhập địa chỉ nhận thư tín'),
        ),
        const SizedBox(height: 24),
        _nextBtn('Tiếp tục', () => _goStep(2), accent: _C.blue),
      ]),
    );
  }

  // ??? Step 2: Employment & loan config ????????????????????????????????????
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(Icons.work_outline, 'Nghề nghiệp & thu nhập'),
        _labelText('Nghề nghiệp hiện tại', required: true),
        _dropdownField(
          value: _occupation.isEmpty ? null : _occupation,
          hint: 'Chọn nghề nghiệp',
          items: ['Nhân viên văn phòng', 'Kinh doanh tự do', 'Công chức/viên chức',
                  'Lao động phổ thông', 'Nội trợ', 'Hưu trí', 'Khác'],
          onChanged: (v) => setState(() => _occupation = v ?? ''),
        ),
        const SizedBox(height: 12),
        _labelText('Tên công ty / đơn vị công tác'),
        TextField(controller: _companyCtrl, style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Nhập tên đơn vị')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Thời gian làm việc'),
            _dropdownField(
              value: _workDuration.isEmpty ? null : _workDuration,
              hint: 'Chọn',
              items: ['< 6 tháng', '6-12 tháng', '1-3 năm', '3-5 năm', '> 5 năm'],
              onChanged: (v) => setState(() => _workDuration = v ?? ''),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Thu nhập hàng tháng (VND)', required: true),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDeco('VD: 15000000'),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        _labelText('Nguồn thu nhập khác (nếu có)'),
        TextField(controller: _otherIncomeCtrl, style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: cho thuê nhà, cổ tức...')),

        _sectionHeader(Icons.home_outlined, 'Tình trạng cư trú'),
        _labelText('Loại nhà ở hiện tại', required: true),
        _radioGroup(
          options: ['Nhà riêng', 'Nhà thuê', 'Ở cùng gia đình', 'Nhà công vụ'],
          selected: _housingStatus,
          onChanged: (v) => setState(() => _housingStatus = v),
        ),

        _sectionHeader(Icons.credit_card_outlined, 'Thông tin khoản vay'),
        _labelText('Mục đích vay', required: true),
        TextField(
          controller: _purposeCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('VD: Mua xe máy, sửa nhà, kinh doanh nhỏ lẻ...'),
        ),
        const SizedBox(height: 12),
        _prefilledField(
          'Loại vay',
          _loanType == 'unsecured'
              ? 'Tín chấp - đã chọn từ bước sản phẩm vay'
              : 'Thế chấp - đã chọn từ bước sản phẩm vay',
        ),
        if (_loanType == 'secured') ...[
          const SizedBox(height: 12),
          _labelText('Mô tả tài sản thế chấp', required: true),
          TextField(
            controller: _collDescCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: Sổ đỏ đất 80m², Hà Nội / Xe ô tô 2022'),
          ),
          const SizedBox(height: 10),
          _labelText('Giá trị tài sản ước tính (VND)'),
          TextField(
            controller: _collValCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: 500000000'),
          ),
        ],
        const SizedBox(height: 16),
        _labelText('Tài khoản nhận giải ngân', required: true),
        if (_loadingAccounts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue)),
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
                Text(_accountsError!, style: const TextStyle(fontSize: 12, color: _C.error)),
                const SizedBox(height: 8),
                TextButton(onPressed: _loadAccounts, child: const Text('Tải lại tài khoản')),
              ],
            ),
          )
        else ...[
          ..._accounts.map((account) => _accountTile(
            account,
            account.id == _disbAccountId,
            () => setState(() => _disbAccountId = account.id),
          )),
          const SizedBox(height: 12),
          _labelText('Tài khoản hoàn trả hàng tháng', required: true),
          ..._accounts.map((account) => _accountTile(
            account,
            account.id == _repayAccountId,
            () => setState(() => _repayAccountId = account.id),
          )),
        ],
        const SizedBox(height: 24),
        _nextBtn(
          'Tiếp tục',
          () => _goStep(3),
          accent: _C.blue,
          disabled: _loadingAccounts || _accounts.isEmpty || _disbAccountId == null || _repayAccountId == null,
        ),
      ]),
    );
  }

  // ??? Step 3: Documents ???????????????????????????????????????????????????
  Widget _buildStep3() {
    final docs = _docs;

    Widget docSection(String title, IconData icon, List<_DocField> fields) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(icon, title),
        ...fields.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _uploadTile(d),
        )),
      ]);
    }

    final idDocs        = docs.where((d) => d.id.startsWith('cccd')).toList();
    final incomeDocs    = docs.where((d) => d.id == 'payslip' || d.id == 'bank_stmt').toList();
    final collDocs      = docs.where((d) => d.id.startsWith('coll')).toList();
    final supportDocs   = docs.where((d) => d.id == 'work_cert').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoNote('Tải ảnh rõ nét, không bị mờ hoặc che khuất thông tin.',
            icon: Icons.info_outline, color: _C.blue, bg: _C.blueLight),
        docSection('Giấy tờ tùy thân',    Icons.badge_outlined,        idDocs),
        docSection('Chứng minh tài chính', Icons.account_balance_wallet_outlined, incomeDocs),
        if (collDocs.isNotEmpty)
          docSection('Giấy tờ thế chấp',  Icons.home_outlined,         collDocs),
        if (supportDocs.isNotEmpty)
          docSection('Tài liệu hỗ trợ',   Icons.description_outlined,  supportDocs),
        const SizedBox(height: 24),
        _nextBtn('Tiếp tục', () => _goStep(4),
            accent: _C.blue, disabled: !_allRequiredDocsUploaded),
        if (!_allRequiredDocsUploaded)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('* Vui lòng tải đủ các tài liệu bắt buộc',
                style: TextStyle(fontSize: 11, color: _C.error)),
          ),
      ]),
    );
  }

  Widget _uploadTile(_DocField doc) {
    final isDone     = _uploadedDocs[doc.id] != null;
    final isUploading = _uploading[doc.id] == true;
    return GestureDetector(
      onTap: isUploading ? null : () => _pickAndUpload(doc.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone ? _C.blueLight : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? _C.blue : _C.border,
            width: isDone ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          isUploading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue))
              : Icon(isDone ? Icons.check_circle : Icons.upload_file_outlined,
                  size: 22, color: isDone ? _C.blue : _C.secondary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(isDone ? 'Đã tải lên · nhấn để thay đổi' : doc.subtitle,
                style: const TextStyle(fontSize: 11, color: _C.secondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: doc.required ? _C.errorLight : const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(doc.required ? 'Bắt buộc' : 'Tùy chọn',
                style: TextStyle(fontSize: 10, color: doc.required ? _C.error : _C.secondary)),
          ),
        ]),
      ),
    );
  }

  // ??? Step 4: Confirm ?????????????????????????????????????????????????????
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
              'Vui lòng chọn kỳ hạn và nhập số tiền vay ở bước đầu tiên.',
              style: TextStyle(fontSize: 14, color: _C.secondary),
            ),
          ],
        ),
      );
    }
    final s = _sel!;
    final product = _selectedLoanProduct(amount, s.months);
    final ratePercent = product != null ? _toPercentRate(product.baseInterestRate) : s.rate;
    final c = _calcLoan(s, amount, ratePercent);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(Icons.check_circle_outline, 'Xác nhận hồ sơ vay'),
        _confirmCard('Thông tin khoản vay', [
          ('Số tiền vay',       _fmtFull(amount)),
          ('Kỳ hạn',            '${s.months} tháng'),
          ('Sản phẩm',          product != null ? '${product.name} (${product.code})' : 'Gói vay phù hợp'),
          ('Lãi suất',          '${ratePercent.toStringAsFixed(2)}%/năm'),
          ('Trả hàng tháng',    _fmtFull(c.monthly)),
          ('Tổng tiền lãi',     _fmtFull(c.totalInterest)),
          ('Tổng phải trả',     _fmtFull(c.total)),
          ('Loại vay',          _loanType == 'secured' ? 'Thế chấp' : 'Tín chấp'),
          ('Mục đích',          _purposeCtrl.text.trim().isEmpty ? '-' : _purposeCtrl.text.trim()),
        ]),
        const SizedBox(height: 12),
        _confirmCard('Thông tin cá nhân', [
          ('Họ và tên',         _user['fullName']!),
          ('Số CCCD',           _user['citizenId']!),
          ('Tình trạng hôn nhân', _maritalStatus.isEmpty ? '-' : _maritalStatus),
          ('Nghề nghiệp',       _occupation.isEmpty ? '-' : _occupation),
          ('Thu nhập/tháng',    _incomeCtrl.text.trim().isEmpty ? '-' : '${_incomeCtrl.text.trim()} VND'),
          ('Tình trạng cư trú', _housingStatus.isEmpty ? '-' : _housingStatus),
        ]),
        const SizedBox(height: 12),
        _confirmCard('Tài khoản', [
          ('Nhận giải ngân', _accountById(_disbAccountId)?.accountNumber ?? '-'),
          ('Hoàn trả',       _accountById(_repayAccountId)?.accountNumber ?? '-'),
        ]),
        const SizedBox(height: 12),
        _confirmCard('Tài liệu', _docs.map((d) =>
          (d.title, _uploadedDocs[d.id] != null ? 'Đã tải lên' : (d.required ? 'Chưa tải' : '- Bỏ qua'))
        ).toList()),
        const SizedBox(height: 12),
        _infoNote(
          'Sau khi gửi hồ sơ, nhân viên tín dụng sẽ duyệt. Khi hồ sơ được duyệt, hợp đồng sẽ hiển thị trong mục Hợp đồng để bạn xem và ký.',
          icon: Icons.info_outline,
          color: _C.blue,
          bg: _C.blueLight,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _C.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Gửi hồ sơ đăng ký vay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ??? Step 5: Success ?????????????????????????????????????????????????????
  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: _C.blueLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, size: 44, color: _C.blue),
          ),
          const SizedBox(height: 20),
          const Text(
            'Hồ sơ vay đã được gửi thành công.\nHồ sơ đang chờ nhân viên tín dụng duyệt.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _C.secondary, height: 1.6),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _C.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Về trang chính',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // ??? Shared widgets ???????????????????????????????????????????????????????
  Widget _sectionHeader(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(children: [
      Icon(icon, size: 18, color: _C.secondary),
      const SizedBox(width: 6),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.secondary)),
    ]),
  );

  Widget _labelText(String label, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: _C.secondary)),
      if (required) const Text(' *', style: TextStyle(fontSize: 12, color: _C.error)),
    ]),
  );

  Widget _prefilledField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _C.secondary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: _C.blueLight, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.check, size: 10, color: _C.blue),
            SizedBox(width: 2),
            Text('Đã có', style: TextStyle(fontSize: 10, color: _C.blue)),
          ]),
        ),
      ]),
      const SizedBox(height: 5),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Text(value, style: const TextStyle(fontSize: 13, color: _C.secondary)),
      ),
    ]),
  );

  Widget _radioGroup({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) => Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
    final isSelected = opt == selected;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onChanged(opt); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _C.blueLight : _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _C.blue : _C.border, width: isSelected ? 1.5 : 0.5),
        ),
        child: Text(opt, style: TextStyle(
            fontSize: 13,
            color: isSelected ? _C.blueDark : _C.primary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }).toList());

  Widget _dropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    value: value,
    hint: Text(hint, style: const TextStyle(fontSize: 13, color: _C.secondary)),
    style: const TextStyle(fontSize: 13, color: _C.primary),
    decoration: _inputDeco('').copyWith(contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
    onChanged: onChanged,
  );

  Widget _accountTile(AccountResolve account, bool selected, VoidCallback onTap) {
    final isSelected = selected;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _C.blueLight : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _C.blue : _C.border, width: isSelected ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Icon(Icons.account_balance_outlined, size: 20,
              color: isSelected ? _C.blue : _C.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(
            '${account.accountNumber} · ${account.accountName}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? _C.primary : _C.secondary,
            ),
          )),
          Text('ID ${account.id}', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isSelected ? _C.blue : _C.secondary)),
        ]),
      ),
    );
  }

  Widget _contractSignPanel() {
    final tpl = _contractTemplate;
    final body = tpl?.templateBody?.trim();
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.draw_outlined, size: 18, color: _C.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tpl == null ? 'Hợp đồng vay' : '${tpl.name} (${tpl.code})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.primary),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_contractError != null)
            Text(_contractError!, style: const TextStyle(fontSize: 12, color: _C.error, height: 1.4))
          else if (tpl == null)
            const Text('Đang tải hợp đồng...', style: TextStyle(fontSize: 12, color: _C.secondary))
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  body == null || body.isEmpty ? (tpl.description ?? 'Hợp đồng chưa có nội dung.') : body,
                  style: const TextStyle(fontSize: 12, color: _C.primary, height: 1.45),
                ),
              ),
            ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _agreementAccepted,
            onChanged: tpl == null ? null : (v) => setState(() {
              _agreementAccepted = v ?? false;
              if (!_agreementAccepted) {
                _devOtpHint = null;
                _otpCtrl.clear();
              }
            }),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Tôi đã đọc và chấp nhận hợp đồng vay',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary),
            ),
          ),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_sendingOtp || !_agreementAccepted || tpl == null) ? null : _sendContractOtp,
                child: _sendingOtp
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Nhận OTP'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: _inputDeco('OTP 6 số'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
          if (_devOtpHint != null && _devOtpHint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Dev OTP: $_devOtpHint', style: const TextStyle(fontSize: 12, color: _C.secondary)),
            ),
        ]),
      ),
    );
  }

  Widget _confirmCard(String title, List<(String, String)> rows) => Container(
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.border),
    ),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.secondary)),
        ),
      ),
      const Divider(height: 1, color: _C.border),
      ...rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.$1, style: const TextStyle(fontSize: 12, color: _C.secondary)),
          const Spacer(),
          Text(r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      )),
    ]),
  );

  Widget _infoNote(String text,
      {required IconData icon, required Color color, required Color bg}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.5))),
      ]),
    );

  Widget _nextBtn(String label, VoidCallback onTap,
      {required Color accent, bool disabled = false}) =>
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: disabled ? Colors.grey.shade300 : accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: disabled ? null : onTap,
        child: Text(label,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: disabled ? _C.secondary : Colors.white,
            )),
      ),
    );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _C.secondary),
    filled: true,
    fillColor: _C.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _C.border, width: 0.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _C.border, width: 0.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _C.blue, width: 1.5)),
  );
}
