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
  bool _loading = false;
  String? _error;
  AccountQr? _qr;
  List<AccountResolve> _accounts = const [];
  String? _selectedAccountNumber;
  final _payloadCtrl = TextEditingController();
  String? _customPayload;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = AccountApi(baseUrl: widget.baseUrl, storage: widget.storage);
      final accounts = await api.myAccounts();
      if (accounts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _accounts = const [];
          _selectedAccountNumber = null;
          _qr = null;
          _error = 'Ban chua co tai khoan. Hay tao so tai khoan sau khi duoc duyet KYC.';
        });
        return;
      }

      final selected = (_selectedAccountNumber != null &&
              accounts.any((e) => e.accountNumber == _selectedAccountNumber))
          ? _selectedAccountNumber
          : accounts.first.accountNumber;

      final qr = await api.myQr(accountNumber: selected);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _selectedAccountNumber = selected;
        _qr = qr;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('No account is assigned')) {
        setState(() => _error = 'Ban chua co tai khoan. Hay tao so tai khoan sau khi duoc duyet KYC.');
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payloadCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanAndTransfer() async {
    final scanned = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(),
      ),
    );

    if (!mounted || scanned == null || scanned.isEmpty) return;

    try {
      final decoded = jsonDecode(scanned);
      if (decoded is! Map) throw Exception('QR payload không đúng');
      final map = decoded.cast<String, dynamic>();
      final accountNumber = map['accountNumber']?.toString().trim();
      final accountName = map['accountName']?.toString().trim();
      if (accountNumber == null || accountNumber.isEmpty) {
        throw Exception('Không tìm thấy accountNumber trong QR');
      }

      if (!mounted) return;
      Navigator.of(context).push(
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _buildFixedQrTab() {
    final qr = _qr;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        if (_accounts.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedAccountNumber,
            decoration: const InputDecoration(
              labelText: 'Tai khoan nguon tao QR',
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
            onChanged: _loading
                ? null
                : (v) async {
                    if (v == null || v == _selectedAccountNumber) return;
                    setState(() {
                      _selectedAccountNumber = v;
                    });
                    await _load();
                  },
          ),
          const SizedBox(height: 12),
        ],
        if (qr == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(_loading ? 'Dang tai QR...' : 'Khong co du lieu QR'),
            ),
          )
        else ...[
          Text('Tai khoan: ${qr.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Ten: ${qr.accountName}'),
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
          onPressed: _loading ? null : _load,
          child: const Text('Tai lai QR'),
        ),
      ],
    );
  }

  Widget _buildCustomQrTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Nhập payload bất kỳ để sinh QR. Dữ liệu này không tự động xác thực.',
          style: TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _payloadCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Payload',
            hintText: '{"accountNumber":"0123456789"}',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final text = _payloadCtrl.text.trim();
                  setState(() => _customPayload = text.isEmpty ? null : text);
                },
                child: const Text('Sinh QR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _payloadCtrl.clear();
                  setState(() => _customPayload = null);
                },
                child: const Text('Xoá'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_customPayload == null)
          const Center(child: Text('Chưa có payload để tạo QR'))
        else
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
                data: _customPayload!,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
          ),
      ],
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
              Tab(text: 'Tạo QR'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFixedQrTab(),
            _buildCustomQrTab(),
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
