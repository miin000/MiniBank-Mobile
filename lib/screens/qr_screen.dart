import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/account_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import 'qr_scan_screen.dart';
import 'transfer_screen.dart';

class QrScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const QrScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _transferAmountCtrl = TextEditingController();

  bool _loadingAccounts = false;
  bool _loadingFixedQr = false;
  bool _loadingTransferQr = false;
  bool _creatingTransferQr = false;
  String? _error;

  List<AccountResolve> _accounts = const [];
  String? _selectedAccountNumber;
  AccountQr? _fixedQr;
  TransferQrIntent? _transferQr;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _transferAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingAccounts = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final accounts = await api.myAccounts();
      if (!mounted) return;

      if (accounts.isEmpty) {
        setState(() {
          _accounts = const [];
          _selectedAccountNumber = null;
          _fixedQr = null;
          _transferQr = null;
          _error = 'Ban chua co tai khoan. Hay tao so tai khoan sau khi duoc duyet KYC.';
        });
        return;
      }

      final selected = (_selectedAccountNumber != null && accounts.any((a) => a.accountNumber == _selectedAccountNumber))
          ? _selectedAccountNumber!
          : accounts.first.accountNumber;

      setState(() {
        _accounts = accounts;
        _selectedAccountNumber = selected;
      });

      await _reloadQrData();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _error = msg.contains('No account is assigned')
            ? 'Ban chua co tai khoan. Hay tao so tai khoan sau khi duoc duyet KYC.'
            : msg;
      });
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _reloadQrData() async {
    final accountNumber = _selectedAccountNumber;
    if (accountNumber == null || accountNumber.isEmpty) return;

    final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
    setState(() {
      _loadingFixedQr = true;
      _loadingTransferQr = true;
      _error = null;
    });

    try {
      final fixedQr = await api.myQr(accountNumber: accountNumber);
      if (!mounted) return;
      setState(() => _fixedQr = fixedQr);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingFixedQr = false);
    }

    try {
      final transferQr = await api.latestTransferQr(accountNumber: accountNumber);
      if (!mounted) return;
      setState(() {
        _transferQr = transferQr;
        _transferAmountCtrl.text = transferQr.amount;
      });
      _syncPolling();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('QR intent not found')) {
        setState(() => _transferQr = null);
      } else {
        setState(() => _error = msg);
      }
      _syncPolling();
    } finally {
      if (mounted) setState(() => _loadingTransferQr = false);
    }
  }

  void _syncPolling() {
    _pollTimer?.cancel();
    final qr = _transferQr;
    if (qr == null || qr.status == 'completed' || qr.status == 'expired') {
      return;
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final accountNumber = _selectedAccountNumber;
      if (accountNumber == null || accountNumber.isEmpty) return;

      try {
        final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
        final latest = await api.latestTransferQr(accountNumber: accountNumber);
        if (!mounted) return;
        setState(() {
          _transferQr = latest;
          if (latest.status == 'completed' || latest.status == 'expired') {
            _pollTimer?.cancel();
          }
        });
      } catch (_) {
        // Quiet polling errors; QR state is refreshed on next cycle.
      }
    });
  }

  String _statusLabel(String status) {
    return switch (status.toLowerCase()) {
      'active' => 'Chờ quét',
      'claimed' => 'Đã được quét',
      'completed' => 'Đã chuyển khoản',
      'expired' => 'Đã hết hạn',
      _ => status,
    };
  }

  Future<void> _createTransferQr() async {
    final accountNumber = _selectedAccountNumber;
    if (accountNumber == null || accountNumber.isEmpty) return;

    final rawAmount = _transferAmountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Số tiền không hợp lệ');
      return;
    }

    setState(() {
      _creatingTransferQr = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final qr = await api.createTransferQr(
        accountNumber: accountNumber,
        amount: amount.toStringAsFixed(2),
      );
      if (!mounted) return;
      setState(() {
        _transferQr = qr;
        _transferAmountCtrl.text = qr.amount;
      });
      _syncPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creatingTransferQr = false);
    }
  }

Future<void> _scanAndTransfer() async {
  final scanned = await Navigator.of(context).push<String?>(
    MaterialPageRoute(builder: (_) => const QrScanScreen()),
  );

  if (!mounted || scanned == null || scanned.isEmpty) return;

  try {
    final decoded = jsonDecode(scanned);
    if (decoded is! Map) throw Exception('QR payload không đúng');
    final map = decoded.cast<String, dynamic>();
    final type = map['type']?.toString().trim();

    if (type == 'transfer_request') {
      final intentToken = map['intentToken']?.toString().trim();
      if (intentToken == null || intentToken.isEmpty) {
        throw Exception('QR chuyển tiền thiếu mã định danh');
      }

      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final claimed = await api.claimTransferQr(intentToken: intentToken);
      if (!mounted) return;

      // ← Bắt kết quả từ TransferScreen
      final transferred = await Navigator.of(context).push<bool?>(
        MaterialPageRoute(
          builder: (_) => TransferScreen(
            baseUrl: widget.baseUrl,
            storage: widget.storage,
            identity: widget.identity,
            prefillToAccountNumber: claimed.accountNumber,
            prefillToAccountName: claimed.accountName,
            prefillAmount: claimed.amount,
            qrTransferIntentId: claimed.intentId,
          ),
        ),
      );

      // ← Nếu chuyển thành công, pop QrScreen về Home với true
      if (mounted && transferred == true) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    final accountNumber = map['accountNumber']?.toString().trim();
    final accountName = map['accountName']?.toString().trim();
    if (accountNumber == null || accountNumber.isEmpty) {
      throw Exception('Không tìm thấy accountNumber trong QR');
    }

    if (!mounted) return;

    // ← Tương tự cho QR cố định
    final transferred = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
          prefillToAccountNumber: accountNumber,
          prefillToAccountName: accountName,
        ),
      ),
    );

    if (mounted && transferred == true) {
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }
}
  Widget _buildFixedQrTab() {
    final qr = _fixedQr;

    return RefreshIndicator(
      onRefresh: _reloadQrData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'QR cố định dùng để quét và chuyển tiền theo số tài khoản.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (_accounts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountNumber,
              decoration: const InputDecoration(
                labelText: 'Tài khoản nhận',
                border: OutlineInputBorder(),
              ),
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.accountNumber,
                      child: Text('${a.accountNumber} - ${a.accountName}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _loadingAccounts
                  ? null
                  : (v) async {
                      if (v == null || v == _selectedAccountNumber) return;
                      setState(() => _selectedAccountNumber = v);
                      await _reloadQrData();
                    },
            ),
            const SizedBox(height: 12),
          ],
          if (_loadingFixedQr)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (qr == null)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('Không có dữ liệu QR')),
            )
          else ...[
            Text('Tài khoản: ${qr.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Tên: ${qr.accountName}'),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 15),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qr.payload,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payload: ${qr.payload}', style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _loadingAccounts ? null : _reloadQrData,
            child: const Text('Tải lại QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferQrTab() {
    final qr = _transferQr;
    final isActive = qr != null && qr.status == 'active';
    final isClaimed = qr != null && qr.status == 'claimed';
    final isCompleted = qr != null && qr.status == 'completed';
    final isExpired = qr != null && qr.status == 'expired';

    return RefreshIndicator(
      onRefresh: _reloadQrData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Nhập số tiền cần nhận, tạo mã và cho người khác quét. Mã sẽ hết hạn sau 15 phút hoặc mất ngay khi đã được quét.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (_accounts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountNumber,
              decoration: const InputDecoration(
                labelText: 'Tài khoản nhận tiền',
                border: OutlineInputBorder(),
              ),
              items: _accounts
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.accountNumber,
                      child: Text('${a.accountNumber} - ${a.accountName}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _creatingTransferQr
                  ? null
                  : (v) async {
                      if (v == null || v == _selectedAccountNumber) return;
                      setState(() => _selectedAccountNumber = v);
                      await _reloadQrData();
                    },
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _transferAmountCtrl,
            enabled: !_creatingTransferQr && !isActive,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Số tiền cần chuyển',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_creatingTransferQr || _loadingAccounts || _selectedAccountNumber == null)
                ? null
                : _createTransferQr,
            child: _creatingTransferQr ? const Text('Đang tạo mã...') : const Text('Tạo mã QR chuyển tiền'),
          ),
          const SizedBox(height: 16),
          if (_loadingTransferQr)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (qr == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Chưa có mã QR chuyển tiền')),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số tiền: ${qr.amount} VND', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Trạng thái: ${_statusLabel(qr.status)}'),
                  const SizedBox(height: 6),
                  Text('Hết hạn: ${qr.expiresAt}'),
                  if (qr.claimedAt != null) ...[
                    const SizedBox(height: 6),
                    Text('Đã quét lúc: ${qr.claimedAt}'),
                  ],
                  if (qr.completedAt != null) ...[
                    const SizedBox(height: 6),
                    Text('Đã chuyển lúc: ${qr.completedAt}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isActive) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 15),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qr.payload,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFEFF6FF)
                      : isClaimed
                          ? const Color(0xFFFFF7ED)
                          : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCompleted
                        ? const Color(0xFF93C5FD)
                        : isClaimed
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Text(
                  isCompleted
                      ? 'Đã chuyển khoản'
                      : isClaimed
                          ? 'Đã có người quét, đang xử lý giao dịch'
                          : isExpired
                              ? 'Mã đã hết hạn'
                              : 'Mã không còn khả dụng',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Payload: ${qr.payload}', style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: _loadingAccounts ? null : _reloadQrData,
            child: const Text('Tải lại trạng thái'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'QR cố định'),
              Tab(text: 'QR chuyển tiền'),
            ],
          ),
        ),
        body: _error != null && _accounts.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(_error!)),
              )
            : TabBarView(
                children: [
                  _buildFixedQrTab(),
                  _buildTransferQrTab(),
                ],
              ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _scanAndTransfer,
            child: const Text('Quét QR để chuyển tiền'),
          ),
        ),
      ),
    );
  }
}
