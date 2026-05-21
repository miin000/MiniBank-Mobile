import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../api/account_api.dart';
import '../api/authed_api.dart';
import '../api/loan_api.dart';
import '../api/profile_api.dart';
import '../auth/auth_storage.dart';
import '../config/app_config.dart';
import '../security/device_identity.dart';

// ??? Design tokens ????????????????????????????????????????????????????????????
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

// ??? Data models ??????????????????????????????????????????????????????????????
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
  _MatrixRow('< 50 tri?u',      30_000_000),
  _MatrixRow('50 - 200 tri?u',  100_000_000),
  _MatrixRow('200 - 500 tri?u', 350_000_000),
  _MatrixRow('> 500 tri?u',     1_000_000_000),
];
const _lCols = [6, 12, 24, 36, 60];
const _lRates = [
  [8.5,  9.0,  9.5, 10.0, 10.5],
  [9.0,  9.5, 10.5, 11.0, 11.5],
  [9.5, 10.5, 11.5, 12.0, 12.5],
  [10.0,11.0, 12.0, 13.0, 14.0],
];

// ??? Document descriptor ??????????????????????????????????????????????????????
class _DocField {
  final String id;
  final String title;
  final String subtitle;
  final bool required;
  _DocField(this.id, this.title, this.subtitle, {this.required = true});
}

// ??? Screen ???????????????????????????????????????????????????????????????????
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
  late ProfileApi _profileApi;
  late AccountApi _accountApi;

  // Step 0 = matrix; 1-4 = form; 5 = success
  int _step = 0;
  _LoanSel? _sel;

  // Pre-filled user info (replace with real fetch from profile service)
  final Map<String, String> _user = {
    'fullName'  : 'Nguy?n Van An',
    'dob'       : '15/05/1990',
    'citizenId' : '034190012345',
    'phone'     : '0912 345 678',
    'email'     : 'nguyenvanan@gmail.com',
    'address'   : '123 Du?ng L�ng, D?ng Da, H� N?i',
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
  final _pageCtrl  = PageController();

  // ??? Document list builders ??????????????????????????????????????????????
  List<_DocField> get _docs {
    return [
      // Identity - always required
      _DocField('cccd_front',  '?nh CCCD m?t tru?c',   'JPG/PNG � t?i da 5MB'),
      _DocField('cccd_back',   '?nh CCCD m?t sau',     'JPG/PNG � t?i da 5MB'),
      // Income proof - always required
      _DocField('payslip',     'Sao k� luong / b?ng luong 3 th�ng g?n nh?t',
                               'PDF ho?c JPG/PNG'),
      _DocField('bank_stmt',   'Sao k� ng�n h�ng 6 th�ng g?n nh?t',
                               'PDF t? ng�n h�ng', required: false),
      // Secured-only
      if (_loanType == 'secured') ...[
        _DocField('coll_title','Gi?y t? t�i s?n th? ch?p',
                               'S? d? / dang k� xe / h?p d?ng mua b�n'),
        _DocField('coll_photo','?nh th?c t? t�i s?n th? ch?p',
                               'JPG/PNG � ch?p r� n�t', required: false),
      ],
      // Unsecured optional support docs
      if (_loanType == 'unsecured')
        _DocField('work_cert', 'X�c nh?n c�ng t�c / H?p d?ng lao d?ng',
                               'Tang t? l? ph� duy?t', required: false),
    ];
  }

  bool get _allRequiredDocsUploaded =>
      _docs.where((d) => d.required).every((d) => _uploadedDocs[d.id] != null);

  // ??? Lifecycle ???????????????????????????????????????????????????????????
  @override
  void initState() {
    super.initState();
    _loanApi = LoanApi(api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage));
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
    _pageCtrl.dispose();
    super.dispose();
  }

  // ??? Helpers ?????????????????????????????????????????????????????????????
  String _fmtMoney(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1).replaceAll('.0', '')} t?';
    if (v >= 1e6) return '${(v / 1e6).round()} tri?u';
    return v.round().toString();
  }

  String _fmtFull(double v) =>
      '${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}?';

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
          _accountsError = 'B?n chua c� t�i kho?n d? dang k� vay.';
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
        throw Exception('Kh�ng d?c du?c file');
      }
      final res  = await http.Response.fromStream(await request.send());
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final url  = data['secure_url']?.toString() ?? '';
      if (!mounted) return;
      setState(() { _uploadedDocs[docId] = url.isNotEmpty ? url : null; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('L?i t?i l�n: $e'), backgroundColor: _C.error));
    } finally {
      if (mounted) setState(() { _uploading[docId] = false; });
    }
  }

  // ??? Submit ??????????????????????????????????????????????????????????????
  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final amount = _enteredAmount();
      if (_sel == null || amount == null) {
        throw Exception('Vui l�ng ch?n k? h?n v� nh?p s? ti?n vay');
      }
      if (_disbAccountId == null || _repayAccountId == null) {
        throw Exception('Vui l�ng ch?n t�i kho?n gi?i ng�n v� ho�n tr?');
      }
      if (_loadingLoanProducts) {
        throw Exception('Dang t?i s?n ph?m vay, vui l�ng th? l?i');
      }
      if (_loanProducts.isEmpty) {
        throw Exception(_loanProductsError ?? 'Chua c� s?n ph?m vay');
      }
      final product = _selectedLoanProduct(amount, _sel!.months);
      if (product == null) {
        throw Exception('Kh�ng t�m th?y s?n ph?m vay ph� h?p v?i s? ti?n/k? h?n d� ch?n');
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
        SnackBar(content: Text('L?i: $e'), backgroundColor: _C.error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ??? Build ???????????????????????????????????????????????????????????????
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
          _step == 0 ? 'Dang k� vay v?n' : _stepTitle(_step),
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
    1 => 'Th�ng tin c� nh�n',
    2 => 'Ngh? nghi?p & kho?n vay',
    3 => 'T�i li?u x�c minh',
    4 => 'X�c nh?n h? so',
    _ => 'Ho�n t?t',
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
        const Text('Ch?n k? h?n v� nh?p s? ti?n vay d? xem l�i su?t',
            style: TextStyle(fontSize: 13, color: _C.secondary)),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('Nh?p s? ti?n vay (VND)'),
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
          _sectionHeader(Icons.inventory_2_outlined, 'San pham vay dang hoat dong'),
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
                'Khong co san pham vay nao phu hop voi so tien va ky han da chon.',
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
                              Text('${p.loanType} � ${p.minTermMonths}-${p.maxTermMonths} thang', style: const TextStyle(fontSize: 11, color: _C.secondary)),
                            ],
                          ),
                        ),
                        Text('${_toPercentRate(p.baseInterestRate).toStringAsFixed(2)}%/nam', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.blueDark)),
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
              child: const Text('Ti?p t?c dang k� vay v?n',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ] else if (_sel != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Vui l�ng nh?p s? ti?n vay d? t�nh l�i v� ti?p t?c.',
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
              _thCell('S? ti?n', isFirst: true),
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
        Text('Vay ${_fmtMoney(amount)} � ${s.months} th�ng',
            style: const TextStyle(fontSize: 12, color: _C.secondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statBox('L�i su?t/nam', '${ratePercent.toStringAsFixed(2)}%', _C.blue)),
          const SizedBox(width: 8),
          Expanded(child: _statBox('Tr? h�ng th�ng', _fmtFull(c.monthly), _C.blue)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _statBox('T?ng l�i', _fmtFull(c.totalInterest), _C.primary)),
          const SizedBox(width: 8),
          Expanded(child: _statBox('T?ng ph?i tr?', _fmtFull(c.total), _C.primary)),
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
        _infoNote('Th�ng tin l?y t? h? so KYC. Vui l�ng b? sung th�m th�ng tin gia d�nh.',
            icon: Icons.info_outline, color: _C.blue, bg: _C.blueLight),

        _sectionHeader(Icons.person_outline, 'Th�ng tin co b?n'),
        _prefilledField('H? v� t�n',       _user['fullName']!),
        Row(children: [
          Expanded(child: _prefilledField('Ng�y sinh',   _user['dob']!)),
          const SizedBox(width: 10),
          Expanded(child: _prefilledField('S? CCCD',     _user['citizenId']!)),
        ]),
        _prefilledField('D?a ch? thu?ng tr�', _user['address']!),
        Row(children: [
          Expanded(child: _prefilledField('S? di?n tho?i', _user['phone']!)),
          const SizedBox(width: 10),
          Expanded(child: _prefilledField('Email',          _user['email']!)),
        ]),

        _sectionHeader(Icons.people_outline, 'Th�ng tin gia d�nh'),
        _labelText('T�nh tr?ng h�n nh�n', required: true),
        _radioGroup(
          options : ['D?c th�n', 'D� k?t h�n', 'Ly h�n', 'G�a'],
          selected: _maritalStatus,
          onChanged: (v) => setState(() => _maritalStatus = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('S? ngu?i ph? thu?c'),
            TextField(
              controller: _dependentsCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDeco('0'),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Tr�nh d? h?c v?n'),
            _dropdownField(
              value: _education.isEmpty ? null : _education,
              hint: 'Ch?n',
              items: ['THPT', 'Cao d?ng', 'D?i h?c', 'Sau d?i h?c', 'Kh�c'],
              onChanged: (v) => setState(() => _education = v ?? ''),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        _labelText('D?a ch? thu t�n (n?u kh�c thu?ng tr�)'),
        TextField(
          controller: _mailAddrCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('Nh?p d?a ch? nh?n thu t�n'),
        ),
        const SizedBox(height: 24),
        _nextBtn('Ti?p t?c', () => _goStep(2), accent: _C.blue),
      ]),
    );
  }

  // ??? Step 2: Employment & loan config ????????????????????????????????????
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader(Icons.work_outline, 'Ngh? nghi?p & thu nh?p'),
        _labelText('Ngh? nghi?p hi?n t?i', required: true),
        _dropdownField(
          value: _occupation.isEmpty ? null : _occupation,
          hint: 'Ch?n ngh? nghi?p',
          items: ['Nh�n vi�n van ph�ng', 'Kinh doanh t? do', 'C�ng ch?c/vi�n ch?c',
                  'Lao d?ng ph? th�ng', 'N?i tr?', 'Huu tr�', 'Kh�c'],
          onChanged: (v) => setState(() => _occupation = v ?? ''),
        ),
        const SizedBox(height: 12),
        _labelText('T�n c�ng ty / don v? c�ng t�c'),
        TextField(controller: _companyCtrl, style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('Nh?p t�n don v?')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Th?i gian l�m vi?c'),
            _dropdownField(
              value: _workDuration.isEmpty ? null : _workDuration,
              hint: 'Ch?n',
              items: ['< 6 th�ng', '6-12 th�ng', '1-3 nam', '3-5 nam', '> 5 nam'],
              onChanged: (v) => setState(() => _workDuration = v ?? ''),
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labelText('Thu nh?p h�ng th�ng (?)', required: true),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDeco('VD: 15000000'),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        _labelText('Ngu?n thu nh?p kh�c (n?u c�)'),
        TextField(controller: _otherIncomeCtrl, style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: cho thu� nh�, c? t?c...')),

        _sectionHeader(Icons.home_outlined, 'T�nh tr?ng cu tr�'),
        _labelText('Lo?i nh� ? hi?n t?i', required: true),
        _radioGroup(
          options: ['Nh� ri�ng', 'Nh� thu�', '? c�ng gia d�nh', 'Nh� c�ng v?'],
          selected: _housingStatus,
          onChanged: (v) => setState(() => _housingStatus = v),
        ),

        _sectionHeader(Icons.credit_card_outlined, 'Th�ng tin kho?n vay'),
        _labelText('M?c d�ch vay', required: true),
        TextField(
          controller: _purposeCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDeco('VD: Mua xe m�y, s?a nh�, kinh doanh nh? l?...'),
        ),
        const SizedBox(height: 12),
        _labelText('Lo?i vay', required: true),
        _radioGroup(
          options: ['T�n ch?p', 'Th? ch?p'],
          selected: _loanType == 'unsecured' ? 'T�n ch?p' : 'Th? ch?p',
          onChanged: (v) => setState(() {
            _loanType = v == 'T�n ch?p' ? 'unsecured' : 'secured';
            _selectedLoanProductId = null;
          }),
        ),
        if (_loanType == 'secured') ...[
          const SizedBox(height: 12),
          _labelText('M� t? t�i s?n th? ch?p', required: true),
          TextField(
            controller: _collDescCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: S? d? d?t 80m�, H� N?i / Xe � t� 2022'),
          ),
          const SizedBox(height: 10),
          _labelText('Gi� tr? t�i s?n u?c t�nh (?)'),
          TextField(
            controller: _collValCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDeco('VD: 500000000'),
          ),
        ],
        const SizedBox(height: 16),
        _labelText('T�i kho?n nh?n gi?i ng�n', required: true),
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
                TextButton(onPressed: _loadAccounts, child: const Text('T?i l?i t�i kho?n')),
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
          _labelText('T�i kho?n ho�n tr? h�ng th�ng', required: true),
          ..._accounts.map((account) => _accountTile(
            account,
            account.id == _repayAccountId,
            () => setState(() => _repayAccountId = account.id),
          )),
        ],
        const SizedBox(height: 24),
        _nextBtn(
          'Ti?p t?c',
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
        _infoNote('T?i ?nh r� n�t, kh�ng b? m? ho?c che khu?t th�ng tin.',
            icon: Icons.info_outline, color: _C.blue, bg: _C.blueLight),
        docSection('Gi?y t? t�y th�n',    Icons.badge_outlined,        idDocs),
        docSection('Ch?ng minh t�i ch�nh', Icons.account_balance_wallet_outlined, incomeDocs),
        if (collDocs.isNotEmpty)
          docSection('Gi?y t? th? ch?p',  Icons.home_outlined,         collDocs),
        if (supportDocs.isNotEmpty)
          docSection('T�i li?u h? tr?',   Icons.description_outlined,  supportDocs),
        const SizedBox(height: 24),
        _nextBtn('Ti?p t?c', () => _goStep(4),
            accent: _C.blue, disabled: !_allRequiredDocsUploaded),
        if (!_allRequiredDocsUploaded)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('* Vui l�ng t?i d? c�c t�i li?u b?t bu?c',
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
            Text(isDone ? 'D� t?i l�n � nh?n d? thay d?i' : doc.subtitle,
                style: const TextStyle(fontSize: 11, color: _C.secondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: doc.required ? _C.errorLight : const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(doc.required ? 'B?t bu?c' : 'Tu? ch?n',
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
              'Vui l�ng ch?n k? h?n v� nh?p s? ti?n vay ? bu?c d?u ti�n.',
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
        _sectionHeader(Icons.check_circle_outline, 'X�c nh?n h? so vay'),
        _confirmCard('Th�ng tin kho?n vay', [
          ('S? ti?n vay',       _fmtFull(amount)),
          ('K? h?n',            '${s.months} th�ng'),
          ('S?n ph?m',          product != null ? '${product.name} (${product.code})' : 'Goi vay phu hop'),
          ('L�i su?t',          '${ratePercent.toStringAsFixed(2)}%/nam'),
          ('Tr? h�ng th�ng',    _fmtFull(c.monthly)),
          ('T?ng ti?n l�i',     _fmtFull(c.totalInterest)),
          ('T?ng ph?i tr?',     _fmtFull(c.total)),
          ('Lo?i vay',          _loanType == 'secured' ? 'Th? ch?p' : 'T�n ch?p'),
          ('M?c d�ch',          _purposeCtrl.text.trim().isEmpty ? '-' : _purposeCtrl.text.trim()),
        ]),
        const SizedBox(height: 12),
        _confirmCard('Th�ng tin c� nh�n', [
          ('H? v� t�n',         _user['fullName']!),
          ('S? CCCD',           _user['citizenId']!),
          ('T�nh tr?ng HN',     _maritalStatus.isEmpty ? '-' : _maritalStatus),
          ('Ngh? nghi?p',       _occupation.isEmpty ? '-' : _occupation),
          ('Thu nh?p/th�ng',    _incomeCtrl.text.trim().isEmpty ? '-' : '${_incomeCtrl.text.trim()}?'),
          ('T�nh tr?ng cu tr�', _housingStatus.isEmpty ? '-' : _housingStatus),
        ]),
        const SizedBox(height: 12),
        _confirmCard('T�i kho?n', [
          ('Nh?n gi?i ng�n', _accountById(_disbAccountId)?.accountNumber ?? '-'),
          ('Ho�n tr?',       _accountById(_repayAccountId)?.accountNumber ?? '-'),
        ]),
        const SizedBox(height: 12),
        _confirmCard('T�i li?u', _docs.map((d) =>
          (d.title, _uploadedDocs[d.id] != null ? '? D� t?i l�n' : (d.required ? '? Chua t?i' : '- B? qua'))
        ).toList()),
        const SizedBox(height: 12),
        _infoNote(
          'Sau khi admin ph� duy?t, h?p d?ng t�n d?ng v� l?ch tr? n? s? du?c g?i v? d? b?n k� x�c nh?n online tru?c khi gi?i ng�n.',
          icon: Icons.draw_outlined, color: _C.blue, bg: _C.blueLight,
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
                : const Text('G?i h? so dang k� vay',
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
          const Text('H? so d� g?i th�nh c�ng!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _C.primary)),
          const SizedBox(height: 10),
          const Text(
            'H? so dang du?c xem x�t trong 1-3 ng�y l�m vi?c.\nK?t qu? s? du?c th�ng b�o qua ?ng d?ng v� email.',
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
            child: const Text('V? trang ch�nh',
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
            Text('D� c�', style: TextStyle(fontSize: 10, color: _C.blue)),
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
            '${account.accountNumber} � ${account.accountName}',
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
