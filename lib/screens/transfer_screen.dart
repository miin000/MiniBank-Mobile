import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/account_api.dart';
import '../api/profile_api.dart';
import '../api/transfer_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _blue = Color(0xFF1B4FD8);
const _blueLight = Color(0xFFEEF2FF);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _gray50 = Color(0xFFF9FAFB);
const _gray100 = Color(0xFFF3F4F6);
const _gray200 = Color(0xFFE5E7EB);
const _gray400 = Color(0xFF9CA3AF);
const _gray600 = Color(0xFF4B5563);
const _gray900 = Color(0xFF111827);

class TransferScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  final String? prefillToAccountNumber;
  final String? prefillToAccountName;
  final String? prefillAmount;
  final int? qrTransferIntentId;

  const TransferScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
    this.prefillToAccountNumber,
    this.prefillToAccountName,
    this.prefillAmount,
    this.qrTransferIntentId,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

enum _TransferStep { form, confirm, pin, otp, success }

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toAccCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  Timer? _resolveDebounce;

  _TransferStep _step = _TransferStep.form;

  bool _loading = false;
  bool _preparingTransaction = false;
  bool _resolvingRecipient = false;
  String? _error;

  List<AccountResolve> _fromAccounts = const [];
  String? _fromAccountNumber;
  String? _toAccountName;
  String? _toAccountError;
  String? _lastResolvedAccount;

  TransferInitiateResponse? _init;
  TransferConfirmResponse? _confirm;

  bool _publicKeyReady = false;
  String _pinValue = '';

  @override
  void initState() {
    super.initState();
    if (widget.prefillToAccountNumber != null) _toAccCtrl.text = widget.prefillToAccountNumber!;
    if (widget.prefillToAccountName?.trim().isNotEmpty == true) {
      _toAccountName = widget.prefillToAccountName!.trim();
      _lastResolvedAccount = widget.prefillToAccountNumber; // ← thêm dòng này
    }
    if (widget.prefillAmount?.trim().isNotEmpty == true) _amountCtrl.text = widget.prefillAmount!.trim();
    _loadFromAccount();
    if (!kIsWeb) _prepareTransferPrereqs();
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _toAccCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ─── Data loaders ─────────────────────────────────────────────────────────

  Future<void> _loadFromAccount() async {
    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final accounts = await api.myAccounts();
      if (!mounted) return;
      if (accounts.isEmpty) {
        setState(() { _error = 'Bạn chưa có tài khoản.'; _fromAccounts = const []; _fromAccountNumber = null; });
        return;
      }
      final selected = (_fromAccountNumber != null && accounts.any((e) => e.accountNumber == _fromAccountNumber))
          ? accounts.firstWhere((e) => e.accountNumber == _fromAccountNumber)
          : accounts.first;
      setState(() { _fromAccounts = accounts; _fromAccountNumber = selected.accountNumber; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _resolveToAccount() async {
    final raw = _toAccCtrl.text.trim();
    if (raw.isEmpty || _resolvingRecipient) return;
    setState(() { _resolvingRecipient = true; _error = null; });
    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final resolved = await api.resolveAccount(raw);
      if (!mounted) return;
      setState(() { _toAccountName = resolved.accountName; _toAccountError = null; _lastResolvedAccount = raw; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _toAccountError = _friendlyError(e); _toAccountName = null; });
    } finally {
      if (mounted) setState(() => _resolvingRecipient = false);
    }
  }

  void _scheduleResolve() {
    _resolveDebounce?.cancel();
    final raw = _toAccCtrl.text.trim();
    if (raw.length != 13 || !RegExp(r'^\d{13}$').hasMatch(raw)) return;
    _resolveDebounce = Timer(const Duration(milliseconds: 400), _resolveToAccount);
  }

  Future<void> _prepareTransferPrereqs() async {
    try { await _ensurePublicKeyRegistered(); } catch (_) {}
  }

  Future<void> _ensurePublicKeyRegistered() async {
    if (_publicKeyReady) return;
    final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
    await api.me();
    final pem = await widget.identity.getOrCreatePublicKeyPem();
    await api.setPublicKey(publicKeyPem: pem);
    _publicKeyReady = true;
  }

  String _canonicalPayload({
    required String fromAcc,
    required String toAcc,
    required String amountFixed,
    required String description,
    required String idempotencyKey,
  }) {
    return 'from=$fromAcc|to=$toAcc|amount=$amountFixed|description=${description.trim()}|idempotencyKey=${idempotencyKey.trim()}';
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('RangeError')) return 'Lỗi ký số. Vui lòng thử lại.';
    if (raw.contains('Invalid OTP')) return 'OTP không đúng. Vui lòng thử lại.';
    if (raw.contains('Invalid PIN')) return 'PIN không đúng. Vui lòng thử lại.';
    if (raw.contains('Transaction PIN is not set')) return 'Bạn chưa cài đặt PIN giao dịch.';
    if (raw.contains('Recipient account not found')) return 'Không tìm thấy tài khoản nhận.';
    if (raw.contains('Recipient account is not active')) return 'Tài khoản nhận không hoạt động.';
    if (raw.contains('Insufficient balance')) return 'Số dư không đủ để thực hiện giao dịch.';
    if (raw.contains('Amount exceeds daily transfer limit')) return 'Vượt hạn mức chuyển tiền trong ngày.';
    return raw.isEmpty ? 'Có lỗi xảy ra. Vui lòng thử lại.' : raw;
  }

  String _normalizeAmount(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  double _parseAmount(String raw) {
    final normalized = _normalizeAmount(raw);
    if (normalized.isEmpty) throw Exception('Số tiền không hợp lệ');
    return double.parse(normalized);
  }

  String _formatAmount(String raw) {
    final normalized = _normalizeAmount(raw);
    if (normalized.isEmpty) return raw;
    final num = double.tryParse(normalized);
    if (num == null) return raw;
    final parts = num.toStringAsFixed(0).split('');
    final result = <String>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.add('.');
      result.add(parts[i]);
    }
    return result.join();
  }

  // ─── Flow logic ───────────────────────────────────────────────────────────

  Future<void> _proceedToConfirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fromAccountNumber == null) { setState(() => _error = 'Không tìm thấy tài khoản nguồn'); return; }
    final normalizedAmount = _normalizeAmount(_amountCtrl.text.trim());
    if (normalizedAmount.isEmpty) {
      setState(() => _error = 'Vui lòng nhập số tiền');
      return;
    }
    final parsedAmount = double.tryParse(normalizedAmount);
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() => _error = 'Số tiền không hợp lệ');
      return;
    }

    final raw = _toAccCtrl.text.trim();
    if (_toAccountName == null || _lastResolvedAccount != raw) {
      await _resolveToAccount();
      if (!mounted) return;
      if (_toAccountName == null) { setState(() => _toAccountError ??= 'Không tìm thấy tài khoản nhận.'); return; }
    }

    setState(() { _error = null; _step = _TransferStep.confirm; });
  }

  Future<void> _proceedToPin() async {
    setState(() { _preparingTransaction = true; _error = null; });
    try {
      await _ensurePublicKeyRegistered();
      if (!mounted) return;
      setState(() { _pinValue = ''; _step = _TransferStep.pin; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _preparingTransaction = false);
    }
  }

  void _pinInput(String digit) {
    if (_pinValue.length >= 6) return;
    setState(() => _pinValue += digit);
    if (_pinValue.length == 6) {
      Future.delayed(const Duration(milliseconds: 200), () => _initiateWithPin(_pinValue));
    }
  }

  void _pinDelete() => setState(() { if (_pinValue.isNotEmpty) _pinValue = _pinValue.substring(0, _pinValue.length - 1); });
  void _pinClear() => setState(() => _pinValue = '');

  Future<void> _initiateWithPin(String pin) async {
    if (_fromAccountNumber == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final toAcc = _toAccCtrl.text.trim();
      final amountInput = _amountCtrl.text.trim();
      final amountValue = _parseAmount(amountInput);
      final amountFixed = amountValue.toStringAsFixed(2);
      final desc = _descCtrl.text.trim();
      final idem = widget.identity.newIdempotencyKey();

      final canonical = _canonicalPayload(
        fromAcc: _fromAccountNumber!, toAcc: toAcc,
        amountFixed: amountFixed, description: desc, idempotencyKey: idem,
      );
      final signature = await widget.identity.signToBase64(canonical);

      final api = TransferApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.initiate(
        fromAccountNumber: _fromAccountNumber!,
        toAccountNumber: toAcc,
        amount: amountFixed,
        description: desc.isEmpty ? null : desc,
        idempotencyKey: idem,
        qrTransferIntentId: widget.qrTransferIntentId,
        signatureBase64: signature,
        pin: pin,
      );

      if (!mounted) return;
      setState(() {
        _init = res;
        _otpCtrl.text = (res.debugOtp?.isNotEmpty == true) ? res.debugOtp! : '';
        _step = _TransferStep.otp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _friendlyError(e); _step = _TransferStep.pin; _pinValue = ''; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmTransfer() async {
    final init = _init;
    if (init == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = TransferApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.confirm(transactionId: init.transactionId, otpCode: _otpCtrl.text.trim());
      if (!mounted) return;
      setState(() { _confirm = res; _step = _TransferStep.success; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_step == _TransferStep.success) {
          Navigator.of(context).pop(true);
          return false;
        }
        if (_step != _TransferStep.form) {
          setState(() {
            _error = null;
            _step = switch (_step) {
              _TransferStep.confirm => _TransferStep.form,
              _TransferStep.pin => _TransferStep.confirm,
              _TransferStep.otp => _TransferStep.pin,
              _ => _TransferStep.form,
            };
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _gray50,
        appBar: _step == _TransferStep.success ? null : _buildAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: _buildStep(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = {
      _TransferStep.form: 'Chuyển tiền',
      _TransferStep.confirm: 'Xác nhận giao dịch',
      _TransferStep.pin: 'Nhập PIN giao dịch',
      _TransferStep.otp: 'Xác thực OTP',
    };

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () {
          if (_step == _TransferStep.form) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _error = null;
              _step = switch (_step) {
                _TransferStep.confirm => _TransferStep.form,
                _TransferStep.pin => _TransferStep.confirm,
                _TransferStep.otp => _TransferStep.pin,
                _ => _TransferStep.form,
              };
            });
          }
        },
      ),
      title: Text(titles[_step] ?? 'Chuyển tiền',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _gray900)),
      bottom: _step != _TransferStep.success && _step != _TransferStep.form
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _StepIndicator(currentStep: _step),
              ),
            )
          : null,
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _TransferStep.form    => _buildFormStep(),
      _TransferStep.confirm => _buildConfirmStep(),
      _TransferStep.pin     => _buildPinStep(),
      _TransferStep.otp     => _buildOtpStep(),
      _TransferStep.success => _buildSuccessStep(),
    };
  }

  // ─── Step 1: Form ─────────────────────────────────────────────────────────

  Widget _buildFormStep() {
    return ListView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(16),
      children: [
        // From account
        _SectionCard(
          title: 'Tài khoản nguồn',
          child: _fromAccountNumber == null
              ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              : DropdownButtonFormField<String>(
                  value: _fromAccountNumber,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  items: _fromAccounts.map((a) => DropdownMenuItem<String>(
                    value: a.accountNumber,
                    child: Text('${a.accountNumber}  –  ${a.accountName}',
                        style: const TextStyle(fontSize: 14)),
                  )).toList(),
                  onChanged: _loading ? null : (v) {
                    if (v != null) setState(() => _fromAccountNumber = v);
                  },
                ),
        ),

        const SizedBox(height: 12),

        // Recipient
        _SectionCard(
          title: 'Người nhận',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _toAccCtrl,
                        enabled: widget.qrTransferIntentId == null,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
                        decoration: const InputDecoration(
                          hintText: '0000000000000',
                          hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0, color: _gray400),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (_toAccountName != null) setState(() { _toAccountName = null; _toAccountError = null; });
                          _scheduleResolve();
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập số tài khoản nhận';
                          if (v.trim().length != 13) return 'Số tài khoản phải đủ 13 chữ số';
                          return null;
                        },
                      ),
                    ),
                  ),
                  if (_resolvingRecipient)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  if (!_resolvingRecipient)
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: _blue),
                      onPressed: _resolveToAccount,
                      tooltip: 'Tìm tài khoản',
                    ),
                ],
              ),
              if (_toAccountName != null) ...[
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: _green),
                    const SizedBox(width: 6),
                    Text(_toAccountName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _green)),
                  ],
                ),
              ],
              if (_toAccountError != null) ...[
                const SizedBox(height: 6),
                Text(_toAccountError!, style: const TextStyle(fontSize: 12, color: _red)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Amount
        _SectionCard(
          title: 'Số tiền',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      enabled: widget.qrTransferIntentId == null,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _blue, letterSpacing: -0.5),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _gray200),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Text('VND', style: TextStyle(fontSize: 16, color: _gray400, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 6),
              // Quick amount chips
              Wrap(
                spacing: 8,
                children: ['100,000', '500,000', '1,000,000', '5,000,000'].map((v) {
                  return GestureDetector(
                    onTap: () => setState(() => _amountCtrl.text = v.replaceAll(',', '')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _blueLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _blue.withOpacity(0.2)),
                      ),
                      child: Text('+$v', style: const TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Description
        _SectionCard(
          title: 'Nội dung chuyển khoản',
          child: TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Nội dung (tuỳ chọn)...',
              hintStyle: TextStyle(color: _gray400, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_error != null) _ErrorBanner(message: _error!),
        if (_error != null) const SizedBox(height: 12),

        _PrimaryButton(
          label: 'Tiếp tục',
          loading: _loading,
          onPressed: _proceedToConfirm,
        ),
      ],
    );
  }

  // ─── Step 2: Confirm ──────────────────────────────────────────────────────

  Widget _buildConfirmStep() {
    final amount = _amountCtrl.text.trim();
    return ListView(
      key: const ValueKey('confirm'),
      padding: const EdgeInsets.all(16),
      children: [
        // Amount hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Số tiền chuyển',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                '${_formatAmount(amount)} VND',
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Transfer details
        _SectionCard(
          title: 'Thông tin giao dịch',
          child: Column(
            children: [
              _ConfirmRow(label: 'Từ tài khoản', value: _fromAccountNumber ?? ''),
              _ConfirmRow(label: 'Đến tài khoản', value: _toAccCtrl.text.trim()),
              _ConfirmRow(label: 'Chủ tài khoản nhận', value: _toAccountName ?? '—'),
              _ConfirmRow(label: 'Phí giao dịch', value: 'Miễn phí', valueColor: _green),
              _ConfirmRow(
                  label: 'Nội dung',
                  value: _descCtrl.text.trim().isEmpty ? '—' : _descCtrl.text.trim(),
                  isLast: true),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Security note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blue.withOpacity(0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_rounded, color: _blue, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Giao dịch được bảo vệ bởi PIN 6 số và mã OTP qua SMS. Không chia sẻ mã với bất kỳ ai.',
                  style: TextStyle(fontSize: 12, color: _blue, height: 1.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_error != null) _ErrorBanner(message: _error!),
        if (_error != null) const SizedBox(height: 12),

        _PrimaryButton(
          label: 'Xác nhận & Nhập PIN',
          loading: _preparingTransaction,
          onPressed: _proceedToPin,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Chỉnh sửa',
          onPressed: () => setState(() { _step = _TransferStep.form; _error = null; }),
        ),
      ],
    );
  }

  // ─── Step 3: PIN ─────────────────────────────────────────────────────────

  Widget _buildPinStep() {
    final amount = _amountCtrl.text.trim();
    return Column(
      key: const ValueKey('pin'),
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 40, color: _blue),
              const SizedBox(height: 12),
              const Text('Nhập PIN giao dịch',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _gray900)),
              const SizedBox(height: 6),
              Text('Xác nhận chuyển ${_formatAmount(amount)} VND',
                  style: const TextStyle(fontSize: 14, color: _gray400)),
              const SizedBox(height: 32),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pinValue.length ? _blue : _gray200,
                    border: i < _pinValue.length ? null : Border.all(color: _gray400, width: 1.5),
                  ),
                )),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: _ErrorBanner(message: _error!),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),

        // Numpad
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else ...[
                _NumpadRow(keys: ['1', '2', '3'], onPressed: _pinInput, onDelete: null),
                _NumpadRow(keys: ['4', '5', '6'], onPressed: _pinInput, onDelete: null),
                _NumpadRow(keys: ['7', '8', '9'], onPressed: _pinInput, onDelete: null),
                _NumpadRow(
                  keys: ['', '0', 'del'],
                  onPressed: (v) { if (v == '') _pinClear(); else _pinInput(v); },
                  onDelete: _pinDelete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 4: OTP ─────────────────────────────────────────────────────────

  Widget _buildOtpStep() {
    final amount = _amountCtrl.text.trim();
    final init = _init;
    return ListView(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gray200),
          ),
          child: Column(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sms_rounded, color: _green, size: 28),
              ),
              const SizedBox(height: 12),
              const Text('Nhập mã OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _gray900)),
              const SizedBox(height: 6),
              Text(
                'Mã OTP đã gửi đến số điện thoại đăng ký.',
                style: const TextStyle(fontSize: 13, color: _gray400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Amount recap
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Số tiền chuyển', style: TextStyle(fontSize: 12, color: _gray400)),
                  Text('${_formatAmount(amount)} VND',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _blue)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Đến', style: TextStyle(fontSize: 12, color: _gray400)),
                  Text(_toAccountName ?? _toAccCtrl.text.trim(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _gray900)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // OTP input
        _SectionCard(
          title: 'Mã xác thực',
          child: TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 12, color: _gray900),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '●●●●●●',
              hintStyle: TextStyle(fontSize: 22, letterSpacing: 8, color: _gray200),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
            ),
          ),
        ),

        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mã hết hạn sau 5 phút',
                style: TextStyle(fontSize: 12, color: _gray400)),
            TextButton(
              onPressed: () {},
              child: const Text('Gửi lại OTP', style: TextStyle(fontSize: 12, color: _blue)),
            ),
          ],
        ),

        if (init?.debugOtp != null && init!.debugOtp!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.developer_mode, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Text('Dev: ${init!.debugOtp}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 8),

        if (_error != null) _ErrorBanner(message: _error!),
        if (_error != null) const SizedBox(height: 12),

        _PrimaryButton(
          label: 'Xác nhận chuyển khoản',
          loading: _loading,
          onPressed: _confirmTransfer,
        ),
        const SizedBox(height: 10),
        _SecondaryButton(
          label: 'Huỷ giao dịch',
          onPressed: () => setState(() {
            _init = null; _step = _TransferStep.form;
            _otpCtrl.clear(); _pinValue = ''; _error = null;
          }),
        ),
      ],
    );
  }

  // ─── Step 5: Success ─────────────────────────────────────────────────────

  Widget _buildSuccessStep() {
    final confirm = _confirm;
    final amount = confirm?.amount ?? _amountCtrl.text.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    // Success animation ring
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 96, height: 96,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: _green, size: 52),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text('Chuyển khoản thành công!',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _gray900)),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatAmount(amount)} VND',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _blue, letterSpacing: -1),
                    ),
                    const SizedBox(height: 28),

                    // Receipt card
                    Container(
                      decoration: BoxDecoration(
                        color: _gray50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gray200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(15), topRight: Radius.circular(15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                const Text('Biên lai giao dịch',
                                    style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (confirm?.completedAt != null)
                                  Text(
                                    confirm!.completedAt!,
                                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Column(
                              children: [
                                _ConfirmRow(label: 'Mã giao dịch', value: confirm?.transactionId.toString() ?? '—',
                                    valueStyle: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _gray600)),
                                _ConfirmRow(label: 'Từ tài khoản', value: confirm?.fromAccountNumber ?? _fromAccountNumber ?? '—'),
                                _ConfirmRow(label: 'Đến tài khoản', value: confirm?.toAccountNumber ?? _toAccCtrl.text.trim()),
                                _ConfirmRow(label: 'Chủ tài khoản nhận', value: _toAccountName ?? '—'),
                                _ConfirmRow(label: 'Nội dung', value: _descCtrl.text.trim().isEmpty ? '—' : _descCtrl.text.trim()),
                                _ConfirmRow(label: 'Trạng thái', value: 'Thành công', valueColor: _green),
                                if (confirm?.fromAvailableBalance != null)
                                  _ConfirmRow(
                                    label: 'Số dư còn lại',
                                    value: '${_formatAmount(confirm!.fromAvailableBalance!)} VND',
                                    isLast: true,
                                    valueStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _gray900),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _comingSoon('Lưu biên lai'),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Lưu biên lai'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gray600,
                      side: const BorderSide(color: _gray200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    label: 'Về trang chủ',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature đang phát triển'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final _TransferStep currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Nhập thông tin', 'Xác nhận', 'Bảo mật', 'Hoàn tất'];
  static final _steps = [_TransferStep.form, _TransferStep.confirm, _TransferStep.pin, _TransferStep.success];

  @override
  Widget build(BuildContext context) {
    final cur = _steps.indexOf(currentStep);
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineIdx = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: lineIdx < cur ? _blue : _gray200,
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx < cur;
        final active = idx == cur;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? _blue : Colors.white,
                border: Border.all(color: done || active ? _blue : _gray200, width: 1.5),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${idx + 1}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : _gray400)),
              ),
            ),
            const SizedBox(height: 4),
            Text(_labels[idx],
                style: TextStyle(fontSize: 9, color: active ? _blue : _gray400, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        );
      }),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _gray400, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;
  final TextStyle? valueStyle;

  const _ConfirmRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(label, style: const TextStyle(fontSize: 13, color: _gray400)),
              ),
              Expanded(
                child: Text(
                  value,
                  style: valueStyle ?? TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: valueColor ?? _gray900,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _gray600,
          side: const BorderSide(color: _gray200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: _red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C), height: 1.4))),
        ],
      ),
    );
  }
}

class _NumpadRow extends StatelessWidget {
  final List<String> keys;
  final void Function(String) onPressed;
  final VoidCallback? onDelete;

  const _NumpadRow({required this.keys, required this.onPressed, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys.map((k) => Expanded(
        child: GestureDetector(
          onTap: k == 'del' ? onDelete : () => onPressed(k),
          child: Container(
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _gray100, width: 0.5),
            ),
            child: k == 'del'
                ? const Icon(Icons.backspace_outlined, size: 22, color: _gray600)
                : k.isEmpty
                    ? const SizedBox()
                    : Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: _gray900)),
          ),
        ),
      )).toList(),
    );
  }
}