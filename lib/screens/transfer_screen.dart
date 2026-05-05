import 'package:flutter/material.dart';

import '../api/account_api.dart';
import '../api/transfer_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';

class TransferScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  final String? prefillToAccountNumber;
  final String? prefillToAccountName;

  const TransferScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
    this.prefillToAccountNumber,
    this.prefillToAccountName,
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

  bool _loading = false;
  String? _error;

  List<AccountResolve> _fromAccounts = const [];
  String? _fromAccountNumber;
  String? _toAccountName;

  TransferInitiateResponse? _init;
  TransferConfirmResponse? _confirm;

  @override
  void initState() {
    super.initState();
    if (widget.prefillToAccountNumber != null) {
      _toAccCtrl.text = widget.prefillToAccountNumber!;
    }
    if (widget.prefillToAccountName != null && widget.prefillToAccountName!.trim().isNotEmpty) {
      _toAccountName = widget.prefillToAccountName!.trim();
    }
    _loadFromAccount();
  }

  @override
  void dispose() {
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final resolved = await api.resolveAccount(raw);
      if (!mounted) return;
      setState(() {
        _toAccountName = resolved.accountName;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _toAccountName = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      final toAcc = _toAccCtrl.text.trim();
      final amountInput = _amountCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final idem = widget.identity.newIdempotencyKey();

      final canonical = _canonicalPayload(
        fromAcc: _fromAccountNumber!,
        toAcc: toAcc,
        amount: amountInput,
        description: desc,
        idempotencyKey: idem,
      );

      final signature = await widget.identity.signToBase64(canonical);

      final api = TransferApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final res = await api.initiate(
        fromAccountNumber: _fromAccountNumber!,
        toAccountNumber: toAcc,
        amount: double.parse(amountInput.replaceAll(',', '.')).toStringAsFixed(2),
        description: desc.isEmpty ? null : desc,
        idempotencyKey: idem,
        signatureBase64: signature,
        pin: pin,
      );

      if (!mounted) return;
      setState(() {
        _init = res;
        if (res.debugOtp != null && res.debugOtp!.isNotEmpty) {
          _otpCtrl.text = res.debugOtp!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
    final approved = await _showReceiptConfirmation();
    if (!approved || !mounted) return;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                          onPressed: _loading || init != null ? null : _resolveToAccount,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (_toAccountName != null) {
                          setState(() => _toAccountName = null);
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nhập số tài khoản nhận';
                        if (v.trim().length != 13) return 'Số tài khoản phải đủ 13 số';
                        return null;
                      },
                      enabled: !_loading && init == null,
                    ),
                    if (_toAccountName != null && _toAccountName!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Chủ tài khoản: $_toAccountName', style: const TextStyle(fontSize: 12)),
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
                      enabled: !_loading && init == null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Nội dung (tuỳ chọn)'),
                      maxLines: 2,
                      enabled: !_loading && init == null,
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
                onPressed: _loading ? null : _confirmAndInitiate,
                child: Text(_loading ? 'Đang tạo giao dịch...' : 'Tiếp tục'),
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
                    TextFormField(
                      controller: _otpCtrl,
                      decoration: const InputDecoration(labelText: 'OTP (6 số)'),
                      keyboardType: TextInputType.number,
                      enabled: !_loading,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _confirmTransfer,
                      child: Text(_loading ? 'Đang xác nhận...' : 'Xác nhận chuyển khoản'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _init = null;
                                _confirm = null;
                                _otpCtrl.clear();
                                _pinCtrl.clear();
                              });
                            },
                      child: const Text('Tạo giao dịch mới'),
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
