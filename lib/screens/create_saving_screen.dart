import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/authed_api.dart';
import '../api/saving_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

// ─── Design tokens (same as ServicesScreen) ───────────────────────────────────
class _C {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAF0);
  static const textPrimary = Color(0xFF0D1B3E);
  static const textSecondary = Color(0xFF6B7299);
  static const green = Color(0xFF00C48C);
  static const blue = Color(0xFF2563EB);
  static const error = Color(0xFFEF4444);
  static const greenGrad = [Color(0xFF00C48C), Color(0xFF00A878)];
}
// ──────────────────────────────────────────────────────────────────────────────

/// Screen for creating a new saving (mở sổ tiết kiệm).
///
/// Flow:
/// 1. Fetch available saving products → user picks one
/// 2. Display product details (rate, term)
/// 3. User enters principal amount (validated against min/max)
/// 4. User picks source account
/// 5. Confirm → POST → success
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
  late SavingApi _savingApi;

  // Step: 0 = picking product, 1 = entering details
  int _step = 0;

  bool _loadingProducts = true;
  bool _loadingAccounts = true;
  bool _submitting = false;

  String? _productError;
  String? _accountError;
  String? _submitError;

  List<SavingProduct> _products = [];
  List<AccountSummary> _accounts = [];

  SavingProduct? _selectedProduct;
  AccountSummary? _selectedAccount;
  AccountSummary? _selectedSettlementAccount;
  bool _autoRenew = false;

  final _principalCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _savingApi = SavingApi(api: api);
    _loadProducts();
    _loadAccounts();
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() { _loadingProducts = true; _productError = null; });
    try {
      final products = await _savingApi.getSavingProducts();
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted) setState(() => _productError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadAccounts() async {
    setState(() { _loadingAccounts = true; _accountError = null; });
    try {
      final accounts = await _savingApi.getMyAccounts();
      if (mounted) setState(() {
        _accounts = accounts;
        if (_accounts.isNotEmpty) {
          _selectedAccount = _accounts.first;
          _selectedSettlementAccount = _accounts.first;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _accountError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) return;
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vui lòng chọn tài khoản nguồn')));
      return;
    }

    setState(() { _submitting = true; _submitError = null; });
    try {
      await _savingApi.createSaving(
        savingProductId: _selectedProduct!.id,
        sourceAccountId: _selectedAccount!.id,
        settlementAccountId: _selectedSettlementAccount?.id,
        autoRenew: _autoRenew,
        principalAmount: _principalCtrl.text.trim().replaceAll('.', ''),
      );
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: Color(0xFFE8FFF6), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline,
                color: _C.green, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Mở sổ thành công!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary)),
          const SizedBox(height: 8),
          const Text('Sổ tiết kiệm của bạn đã được tạo và đang chờ kích hoạt.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _C.textSecondary)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(true); // return success
              },
              child: const Text('Hoàn tất'),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Formatters ────────────────────────────────────────────────────────────
  String _fmtCurrency(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _termLabel(SavingProduct p) =>
      '${p.termValue} ${p.termUnit == 'MONTH' ? 'tháng' : 'năm'}';

  // ─── Product picker step ───────────────────────────────────────────────────
  Widget _buildProductStep() {
    if (_loadingProducts) {
      return const Expanded(
          child: Center(child: CircularProgressIndicator()));
    }
    if (_productError != null) {
      return Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: _C.textSecondary),
            const SizedBox(height: 12),
            Text(_productError!,
                style: const TextStyle(color: _C.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadProducts, child: const Text('Thử lại')),
          ]),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = _products[i];
          final isSelected = _selectedProduct?.id == p.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedProduct = p;
                _step = 1;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8FFF6)
                    : _C.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSelected ? _C.green : _C.border,
                    width: isSelected ? 1.5 : 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: _C.greenGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.savings_outlined,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.textPrimary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _tag('${p.baseInterestRate}%/năm', _C.green),
                      const SizedBox(width: 6),
                      _tag(_termLabel(p), _C.blue),
                    ]),
                    if (p.minOpenAmount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          'Tối thiểu: ${_fmtCurrency(p.minOpenAmount!)} ₫',
                          style: const TextStyle(
                              fontSize: 11, color: _C.textSecondary)),
                    ],
                  ]),
                ),
                Icon(
                    isSelected ? Icons.check_circle : Icons.chevron_right,
                    color: isSelected ? _C.green : _C.textSecondary,
                    size: 20),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  // ─── Detail entry step ─────────────────────────────────────────────────────
  Widget _buildDetailStep() {
    final p = _selectedProduct!;
    return Expanded(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: _C.greenGrad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: _C.green.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.savings_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(p.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _step = 0; _selectedProduct = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Đổi sản phẩm',
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _productStat('Lãi suất', '${p.baseInterestRate}%/năm')),
                  Expanded(child: _productStat('Kỳ hạn', _termLabel(p))),
                  if (p.capitalized)
                    Expanded(child: _productStat('Lãi suất', 'Kép')),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Amount input
            const Text('Số tiền gửi',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _principalCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ThousandsSeparatorInputFormatter(),
              ],
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(color: _C.textSecondary),
                suffixText: '₫',
                suffixStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.textSecondary),
                filled: true,
                fillColor: _C.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.green, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.error)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập số tiền';
                final raw = v.replaceAll('.', '');
                final n = double.tryParse(raw);
                if (n == null || n <= 0) return 'Số tiền không hợp lệ';
                if (p.minOpenAmount != null && n < p.minOpenAmount!) {
                  return 'Tối thiểu ${_fmtCurrency(p.minOpenAmount!)} ₫';
                }
                if (p.maxOpenAmount != null && n > p.maxOpenAmount!) {
                  return 'Tối đa ${_fmtCurrency(p.maxOpenAmount!)} ₫';
                }
                return null;
              },
            ),
            if (p.minOpenAmount != null || p.maxOpenAmount != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                if (p.minOpenAmount != null)
                  Text('Tối thiểu: ${_fmtCurrency(p.minOpenAmount!)} ₫',
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary)),
                if (p.minOpenAmount != null && p.maxOpenAmount != null)
                  const Text('  •  ',
                      style: TextStyle(color: _C.textSecondary)),
                if (p.maxOpenAmount != null)
                  Text('Tối đa: ${_fmtCurrency(p.maxOpenAmount!)} ₫',
                      style: const TextStyle(
                          fontSize: 11, color: _C.textSecondary)),
              ]),
            ],
            const SizedBox(height: 20),

            // Source account picker
            const Text('Tài khoản nguồn',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const SizedBox(height: 8),
            if (_loadingAccounts)
              const Center(child: CircularProgressIndicator())
            else if (_accountError != null)
              Text('Lỗi tải tài khoản: $_accountError',
                  style: const TextStyle(color: _C.error))
            else if (_accounts.isEmpty)
              const Text('Không có tài khoản khả dụng',
                  style: TextStyle(color: _C.textSecondary))
            else
              ...(_accounts.map((acc) => GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedAccount = acc;
                    _selectedSettlementAccount ??= acc;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedAccount?.id == acc.id
                        ? const Color(0xFFEFF6FF)
                        : _C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _selectedAccount?.id == acc.id
                            ? _C.blue
                            : _C.border,
                        width: _selectedAccount?.id == acc.id ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _C.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_outlined,
                          color: _C.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(acc.accountName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _C.textPrimary)),
                      Text(acc.accountNumber,
                          style: const TextStyle(
                              fontSize: 11, color: _C.textSecondary)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${_fmtCurrency(acc.availableBalance)} ₫',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.textPrimary)),
                      const Text('Khả dụng',
                          style: TextStyle(
                              fontSize: 10, color: _C.textSecondary)),
                    ]),
                  ]),
                ),
              ))),
            const SizedBox(height: 20),

            // Settlement account picker
            const Text('Tài khoản nhận tất toán',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const SizedBox(height: 8),
            if (_loadingAccounts)
              const Center(child: CircularProgressIndicator())
            else if (_accountError != null)
              Text('Lỗi tải tài khoản: $_accountError',
                  style: const TextStyle(color: _C.error))
            else if (_accounts.isEmpty)
              const Text('Không có tài khoản khả dụng',
                  style: TextStyle(color: _C.textSecondary))
            else
              ...(_accounts.map((acc) => GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSettlementAccount = acc);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedSettlementAccount?.id == acc.id
                        ? const Color(0xFFEFF6FF)
                        : _C.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _selectedSettlementAccount?.id == acc.id
                            ? _C.blue
                            : _C.border,
                        width: _selectedSettlementAccount?.id == acc.id ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _C.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_outlined,
                          color: _C.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(acc.accountName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _C.textPrimary)),
                      Text(acc.accountNumber,
                          style: const TextStyle(
                              fontSize: 11, color: _C.textSecondary)),
                    ])),
                    if (_selectedAccount?.id == acc.id)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Mặc định',
                            style: TextStyle(fontSize: 10, color: _C.green)),
                      ),
                  ]),
                ),
              ))),
            const SizedBox(height: 12),

            // Auto renew toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tự động tái tục',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text(
                  'Đáo hạn sẽ tự mở sổ mới theo kỳ hạn hiện tại',
                  style: TextStyle(fontSize: 12, color: _C.textSecondary),
                ),
                value: _autoRenew,
                onChanged: (value) => setState(() => _autoRenew = value),
              ),
            ),
            const SizedBox(height: 20),

            // Error
            if (_submitError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: _C.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.error.withValues(alpha: 0.2))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: _C.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_submitError!,
                        style: const TextStyle(fontSize: 12, color: _C.error)),
                  ),
                ]),
              ),

            // Submit button
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Mở sổ tiết kiệm',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productStat(String label, String value) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
    ]);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _C.textPrimary),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _step == 0 ? 'Chọn sản phẩm tiết kiệm' : 'Chi tiết mở sổ',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
              letterSpacing: -0.3),
        ),
        // Step indicator
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _step == 0 ? 0.5 : 1.0,
            backgroundColor: _C.border,
            color: _C.green,
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _step == 0
                  ? 'Chọn kỳ hạn phù hợp với bạn'
                  : 'Nhập thông tin chi tiết',
              style: const TextStyle(
                  fontSize: 13, color: _C.textSecondary),
            ),
          ),
          if (_step == 0) _buildProductStep() else _buildDetailStep(),
        ],
      ),
    );
  }
}

// ─── Thousands separator formatter ────────────────────────────────────────────
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