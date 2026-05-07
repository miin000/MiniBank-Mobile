import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/account_api.dart';
import '../api/profile_api.dart';
import '../api/transfer_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

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

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();

  final _toAccCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  Timer? _resolveDebounce;

  bool _loading = false;
  bool _preparingTransaction = false;
  bool _resolvingRecipient = false;
  String? _error;

  List<AccountResolve> _fromAccounts = const [];
  String? _fromAccountNumber;
  String? _toAccountName;
  String? _toAccountError;
  String? _lastResolvedAccount; // Track which account was last resolved successfully

  TransferInitiateResponse? _init;
  TransferConfirmResponse? _confirm;

  bool _publicKeyReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillToAccountNumber != null) {
      _toAccCtrl.text = widget.prefillToAccountNumber!;
    }
    if (widget.prefillToAccountName != null && widget.prefillToAccountName!.trim().isNotEmpty) {
      _toAccountName = widget.prefillToAccountName!.trim();
    }
    if (widget.prefillAmount != null && widget.prefillAmount!.trim().isNotEmpty) {
      _amountCtrl.text = widget.prefillAmount!.trim();
    }
    _loadFromAccount();
    if (!kIsWeb) {
      _prepareTransferPrereqs();
    }
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _toAccCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromAccount() async {
    try {
      final accountApi = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final accounts = await accountApi.myAccounts();
      if (!mounted) return;
      if (accounts.isEmpty) {
        setState(() {
          _error = 'Ban chua co tai khoan. Hay tao so tai khoan sau khi duoc duyet KYC.';
          _fromAccounts = const [];
          _fromAccountNumber = null;
        });
        return;
      }

      final selected = (_fromAccountNumber != null &&
              accounts.any((e) => e.accountNumber == _fromAccountNumber))
          ? accounts.firstWhere((e) => e.accountNumber == _fromAccountNumber)
          : accounts.first;
      setState(() {
        _fromAccounts = accounts;
        _fromAccountNumber = selected.accountNumber;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _resolveToAccount() async {
    final raw = _toAccCtrl.text.trim();
    if (raw.isEmpty) return;
    if (_resolvingRecipient) {
      debugPrint('transfer: resolve already in progress, skipping duplicate call');
      return;
    }

    debugPrint('transfer: resolve recipient start acc=$raw');

    setState(() {
      _resolvingRecipient = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final resolved = await api.resolveAccount(raw);
      if (!mounted) return;
      setState(() {
        _toAccountName = resolved.accountName;
        _toAccountError = null;
        _lastResolvedAccount = raw; // Mark as successfully resolved
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('resolveAccount error: $e');
      setState(() {
        _toAccountError = _friendlyError(e);
        _toAccountName = null;
      });
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

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('RangeError')) return 'Loi ky so. Vui long thu lai.';
    if (raw.contains('Invalid OTP')) return 'OTP khong dung. Vui long thu lai.';
    if (raw.contains('Invalid PIN')) return 'PIN khong dung. Vui long thu lai.';
    if (raw.contains('Transaction PIN is not set')) return 'Ban chua cai dat PIN giao dich.';
    if (raw.contains('Recipient account not found')) return 'Khong tim thay tai khoan nhan.';
    if (raw.contains('Recipient account is not active')) return 'Tai khoan nhan khong hoat dong.';
    if (raw.contains('Insufficient balance')) return 'So du khong du.';
    if (raw.contains('Amount exceeds daily transfer limit')) return 'Vuot han muc chuyen trong ngay.';
    if (raw.contains('SMS service is not configured')) return 'SMS OTP chua duoc cau hinh.';
    return raw.isEmpty ? 'Co loi xay ra. Vui long thu lai.' : raw;
  }

  Future<void> _prepareTransferPrereqs() async {
    try {
      await _ensurePublicKeyRegistered();
    } catch (e) {
      // Ignore preflight errors; they will surface during initiate if needed.
      debugPrint('transfer: preflight public key error: $e');
    }
  }

  Future<void> _ensurePublicKeyRegistered() async {
    if (_publicKeyReady) return;
    final api = ProfileApi(baseUrl: widget.baseUrl, storage: widget.storage);
    await api.me();
    final publicKeyPem = await widget.identity.getOrCreatePublicKeyPem();
    await api.setPublicKey(publicKeyPem: publicKeyPem);
    _publicKeyReady = true;
  }

  static String _canonicalPayload({
    required String fromAcc,
    required String toAcc,
    required String amount,
    required String description,
    required String idempotencyKey,
  }) {
    final desc = description.trim();
    final idem = idempotencyKey.trim();
    // Backend normalizes amount to scale 2 (HALF_UP). We assume user inputs valid decimal.
    // Ensure string has 2 decimals.
    final parsed = double.tryParse(amount.replaceAll(',', '.'));
    if (parsed == null) throw Exception('Số tiền không hợp lệ');
    final amt = parsed.toStringAsFixed(2);
    return 'from=$fromAcc|to=$toAcc|amount=$amt|description=$desc|idempotencyKey=$idem';
  }

  Future<void> _initiate({required String pin}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountNumber == null) {
      setState(() => _error = 'Không tìm thấy tài khoản nguồn');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _confirm = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final toAcc = _toAccCtrl.text.trim();
      final amountInput = _amountCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final idem = widget.identity.newIdempotencyKey();

      debugPrint('transfer: initiate start from=$_fromAccountNumber to=$toAcc amount=$amountInput');

      final canonical = _canonicalPayload(
        fromAcc: _fromAccountNumber!,
        toAcc: toAcc,
        amount: amountInput,
        description: desc,
        idempotencyKey: idem,
      );

      debugPrint('transfer: signing payload...');
      final signature = await widget.identity.signToBase64(canonical);
      debugPrint('transfer: signature ok in ${stopwatch.elapsedMilliseconds}ms');

      final api = TransferApi(baseUrl: widget.baseUrl, storage: widget.storage);
      debugPrint('transfer: calling initiate API...');
      final res = await api.initiate(
        fromAccountNumber: _fromAccountNumber!,
        toAccountNumber: toAcc,
        amount: double.parse(amountInput.replaceAll(',', '.')).toStringAsFixed(2),
        description: desc.isEmpty ? null : desc,
        idempotencyKey: idem,
        qrTransferIntentId: widget.qrTransferIntentId,
        signatureBase64: signature,
        pin: pin,
      );

      if (!mounted) return;
      setState(() {
        _init = res;
        _otpCtrl.text = (res.debugOtp != null && res.debugOtp!.isNotEmpty)
            ? res.debugOtp!
            : '123456';
      });
      debugPrint('transfer: initiate done in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('transfer initiate error: $e');
      debugPrintStack(stackTrace: st);
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showReceiptConfirmation() async {
    if (!_formKey.currentState!.validate()) return false;
    if (_fromAccountNumber == null) {
      setState(() => _error = 'Không tìm thấy tài khoản nguồn');
      return false;
    }

    final toAcc = _toAccCtrl.text.trim();
    final amountInput = _amountCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    final approved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.receipt_long, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Biên lai xác nhận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Kiểm tra lại thông tin trước khi nhập PIN.', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Số tiền', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(
                      '$amountInput VND',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                    _ConfirmRow(label: 'Tài khoản nguồn', value: _fromAccountNumber ?? ''),
                    _ConfirmRow(label: 'Tài khoản nhận', value: toAcc),
                    if (_toAccountName != null && _toAccountName!.isNotEmpty)
                      _ConfirmRow(label: 'Chủ tài khoản', value: _toAccountName!),
                    _ConfirmRow(label: 'Nội dung', value: desc.isEmpty ? '---' : desc),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Xem lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return approved == true;
  }

  Future<String?> _showPinPrompt() async {
    _pinCtrl.clear();

    String? localError;
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(Icons.lock, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Nhập PIN giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Sau khi nhập PIN, hệ thống sẽ gửi OTP để xác thực giao dịch.', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(labelText: 'PIN (6 số)'),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(localError!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Huỷ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final pin = _pinCtrl.text.trim();
                            if (pin.length != 6) {
                              setModalState(() {
                                localError = 'Vui lòng nhập PIN 6 số';
                              });
                              return;
                            }
                            Navigator.of(ctx).pop(pin);
                          },
                          child: const Text('Xác nhận PIN'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndInitiate() async {
    final raw = _toAccCtrl.text.trim();
    
    // Check if recipient needs resolution or if input changed since last resolution
    if (_toAccountName == null || _toAccountName!.isEmpty || _lastResolvedAccount != raw) {
      if (_resolvingRecipient) {
        // If already resolving, wait a bit and try to resolve again
        setState(() => _error = 'Dang xac nhan tai khoan nhan, vui long doi...');
        await Future.delayed(const Duration(milliseconds: 200));
      }
      await _resolveToAccount();
      if (!mounted) return;
      if (_toAccountName == null || _toAccountName!.isEmpty) {
        setState(() => _toAccountError = _toAccountError ?? 'Khong tim thay tai khoan nhan.');
        return;
      }
    }

    final approved = await _showReceiptConfirmation();
    if (!approved || !mounted) return;

    setState(() => _preparingTransaction = true);
    try {
      await _ensurePublicKeyRegistered();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _preparingTransaction = false;
      });
      return;
    }
    if (mounted) {
      setState(() => _preparingTransaction = false);
    }

    final pin = await _showPinPrompt();
    if (pin == null || pin.isEmpty) return;

    await _initiate(pin: pin);

    if (mounted) _pinCtrl.clear();
  }

  Future<void> _confirmTransfer() async {
    final init = _init;
    if (init == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = TransferApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.confirm(
        transactionId: init.transactionId,
        otpCode: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _confirm = res;
      });
      final shouldReturnHome = await _showSuccessReceipt(res);
      if (!mounted) return;
      if (shouldReturnHome == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('transfer confirm error: $e');
      setState(() {
        _error = _friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showSuccessReceipt(TransferConfirmResponse res) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hóa đơn giao dịch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mã giao dịch: ${res.transactionId}'),
                const SizedBox(height: 6),
                Text('Trạng thái: ${res.status}'),
                const SizedBox(height: 6),
                Text('Từ: ${res.fromAccountNumber}'),
                const SizedBox(height: 6),
                Text('Đến: ${res.toAccountNumber}'),
                const SizedBox(height: 6),
                Text('Số tiền: ${res.amount} VND'),
                if (res.completedAt != null) ...[
                  const SizedBox(height: 6),
                  Text('Thời gian: ${res.completedAt}'),
                ],
                if (res.fromAvailableBalance != null) ...[
                  const SizedBox(height: 6),
                  Text('Số dư còn lại: ${res.fromAvailableBalance} VND'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Về trang chủ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final init = _init;

    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển tiền')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _fromAccountNumber == null
                  ? const Text('Dang tai tai khoan nguon...')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tai khoan nguon', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _fromAccountNumber,
                          items: _fromAccounts
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: a.accountNumber,
                                  child: Text('${a.accountNumber}${a.accountName.isEmpty ? '' : ' (${a.accountName})'}'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _loading || _init != null
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  final selected = _fromAccounts.firstWhere((a) => a.accountNumber == v);
                                  setState(() {
                                    _fromAccountNumber = selected.accountNumber;
                                  });
                                },
                        ),
                      ],
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin chuyển tiền', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _toAccCtrl,
                      decoration: InputDecoration(
                        labelText: 'Số tài khoản nhận',
                        suffixIcon: IconButton(
                          onPressed: _loading || _resolvingRecipient || init != null ? null : _resolveToAccount,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (_toAccountName != null) {
                          setState(() => _toAccountName = null);
                        }
                        _scheduleResolve();
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nhập số tài khoản nhận';
                        if (v.trim().length != 13) return 'Số tài khoản phải đủ 13 số';
                        return null;
                      },
                      enabled: init == null && widget.qrTransferIntentId == null,
                    ),
                    if (_toAccountName != null && _toAccountName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Chủ tài khoản: $_toAccountName', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    if (_toAccountError != null && _toAccountError!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _toAccountError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nhập số tiền';
                        final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
                        if (parsed == null || parsed <= 0) return 'Số tiền không hợp lệ';
                        return null;
                      },
                      enabled: init == null && widget.qrTransferIntentId == null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Nội dung (tuỳ chọn)'),
                      maxLines: 2,
                      enabled: init == null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            if (init == null)
              FilledButton(
                onPressed: (_loading || _preparingTransaction) ? null : _confirmAndInitiate,
                child: _preparingTransaction
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('Đang chuẩn bị...'),
                        ],
                      )
                    : Text(_loading ? 'Đang tạo giao dịch...' : 'Tiếp tục'),
              ),
            if (init != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Xác thực giao dịch', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Người nhận: ${init.toAccountName}'),
                    const SizedBox(height: 6),
                    Text('Mã giao dịch: ${init.transactionCode}'),
                    const SizedBox(height: 12),
                    if (_confirm == null && _error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDC2626)),
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFFFEE2E2),
                        ),
                        child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _otpCtrl,
                      decoration: const InputDecoration(labelText: 'OTP (6 số)'),
                      keyboardType: TextInputType.number,
                      enabled: !_loading && _confirm == null,
                    ),
                    const SizedBox(height: 16),
                    if (_confirm == null) ...[
                      FilledButton(
                        onPressed: _loading ? null : _confirmTransfer,
                        child: Text(_loading ? 'Đang xác nhận...' : 'Xác nhận chuyển khoản'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _init = null;
                                _confirm = null;
                                _otpCtrl.clear();
                                _pinCtrl.clear();
                                _error = null;
                              });
                            },
                      child: Text(_confirm != null ? 'Tạo giao dịch mới' : 'Huỷ giao dịch'),
                    ),
                  ],
                ),
              ),
            ],
            if (_confirm != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kết quả: ${_confirm!.status}\nSố dư khả dụng: ${_confirm!.fromAvailableBalance ?? ''}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
