import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/contract_api.dart';
import '../auth/auth_storage.dart';

class _C {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAF0);
  static const textPrimary = Color(0xFF0D1B3E);
  static const textSecondary = Color(0xFF6B7299);
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF00A86B);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
}

/// Shows the current user's loan applications and any pending contracts to sign.
/// Signing a loan contract triggers Loan creation on the backend.
class LoanContractsScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const LoanContractsScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<LoanContractsScreen> createState() => _LoanContractsScreenState();
}

class _LoanContractsScreenState extends State<LoanContractsScreen> {
  late ContractApi _contractApi;

  List<LoanApplicationItem> _applications = [];
  List<MobileContract> _contracts = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _contractApi = ContractApi(api: api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _contractApi.getMyLoanApplications(),
        _contractApi.getMobileContracts(),
      ]);
      if (!mounted) return;
      setState(() {
        _applications = results[0] as List<LoanApplicationItem>;
        _contracts = (results[1] as List<MobileContract>)
            .where((c) => c.isForLoan)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatCurrency(double amount) {
    final s = amount.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(s[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()} VND';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return raw;
    }
  }

  Color _appStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _C.green;
      case 'pending':
        return _C.orange;
      case 'rejected':
        return _C.red;
      default:
        return _C.blue;
    }
  }

  String _appStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Đã duyệt';
      case 'pending':
        return 'Chờ duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'more_info_needed':
        return 'Cần bổ sung';
      default:
        return status;
    }
  }

  /// Find a pending (unsigned) contract for a given loan application id
  MobileContract? _pendingContractFor(int appId) {
    for (final c in _contracts) {
      if (c.ownerId == appId && !c.isSigned) return c;
    }
    return null;
  }

  // ─── Sign contract flow ───────────────────────────────────────────────────

  Future<void> _signContract(MobileContract contract, LoanApplicationItem app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Ký hợp đồng vay',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.textPrimary),
        ),
        content: Text(
          'Xác nhận ký hợp đồng cho khoản vay ${_formatCurrency(app.requestedAmount)}, '
          '${app.requestedTermMonths} tháng?\n\n'
          'Sau khi ký, khoản vay sẽ được giải ngân ngay vào tài khoản của bạn.',
          style: const TextStyle(fontSize: 14, color: _C.textSecondary),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ký hợp đồng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _contractApi.signMobileContract(contract.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn vay đã gửi thành công! Chờ duyệt.')),
      );
      Navigator.of(context).pop(true);
      _load(); // refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: _C.red,
        ),
      );
    }
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _applicationCard(LoanApplicationItem app) {
    final pendingContract = _pendingContractFor(app.id);
    final canSign =
        app.status.toLowerCase() == 'approved' && pendingContract != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canSign
              ? _C.blue.withOpacity(0.4)
              : _C.border,
          width: canSign ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.productName ?? 'Khoản vay',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đơn #${app.id}  •  ${app.requestedTermMonths} tháng',
                      style: const TextStyle(
                          fontSize: 12, color: _C.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _appStatusColor(app.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _appStatusLabel(app.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _appStatusColor(app.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(app.requestedAmount),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary),
          ),
          if (app.purpose != null && app.purpose!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mục đích: ${app.purpose}',
              style:
                  const TextStyle(fontSize: 12, color: _C.textSecondary),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Ngày gửi: ${_formatDate(app.submittedAt)}',
            style:
                const TextStyle(fontSize: 12, color: _C.textSecondary),
          ),

          // Sign contract button — only when approved + has pending contract
          if (canSign) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: _C.border),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: _C.blue),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Hợp đồng đã sẵn sàng — ký để nhận giải ngân',
                    style: TextStyle(fontSize: 12, color: _C.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _signContract(pendingContract, app),
                icon: const Icon(Icons.draw_rounded, size: 16),
                label: const Text('Ký hợp đồng & nhận giải ngân'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          // Already signed
          if (app.status.toLowerCase() == 'approved' &&
              pendingContract == null) ...[
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(Icons.check_circle_outline,
                    size: 14, color: _C.green),
                SizedBox(width: 6),
                Text(
                  'Hợp đồng đã ký — khoản vay đang hoạt động',
                  style: TextStyle(fontSize: 12, color: _C.green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _C.blue),
        ),
        title: const Text(
          'Đơn vay & Hợp đồng',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _C.blue),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Lỗi: $_error'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Thử lại')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _C.blue,
                  child: _applications.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có đơn vay nào',
                            style: TextStyle(color: _C.textSecondary),
                          ),
                        )
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            // Info banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _C.blue.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _C.blue.withOpacity(0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: _C.blue),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Đơn vay được duyệt sẽ có hợp đồng cần ký. Sau khi ký, khoản vay xuất hiện trong tab "Khoản vay".',
                                      style: TextStyle(
                                          fontSize: 12, color: _C.blue),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ..._applications.map(_applicationCard),
                          ],
                        ),
                ),
    );
  }
}