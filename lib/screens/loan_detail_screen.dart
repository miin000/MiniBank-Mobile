import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/loan_api.dart';
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

class LoanDetailScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final int loanId;

  const LoanDetailScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.loanId,
  });

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  late LoanApi _loanApi;
  LoanDetail? _detail;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _loanApi.getLoanById(widget.loanId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatCurrency(double amount) => amount.toStringAsFixed(0);

  String _formatCurrencyText(double? amount) {
    if (amount == null) return '-';
    return '${_formatCurrency(amount)} VND';
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (_) {
      return dateString;
    }
  }

  String _formatFrequency(String value) {
    switch (value.toUpperCase()) {
      case 'MONTHLY':
        return 'Hang thang';
      case 'WEEKLY':
        return 'Hang tuan';
      case 'QUARTERLY':
        return 'Hang quy';
      case 'YEARLY':
        return 'Hang nam';
      default:
        return value;
    }
  }

  String _formatMethod(String value) {
    switch (value.toUpperCase()) {
      case 'REDUCING_BALANCE':
        return 'Du no giam dan';
      case 'FLAT':
        return 'Lai suat co dinh';
      default:
        return value;
    }
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('active') || lower.contains('open')) return _C.green;
    if (lower.contains('pending') || lower.contains('processing')) return _C.orange;
    if (lower.contains('closed') || lower.contains('completed')) return Colors.grey;
    if (lower.contains('overdue') || lower.contains('failed')) return _C.red;
    return _C.blue;
  }

  String _statusLabel(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('active') || lower.contains('open')) return 'Hoạt động';
    if (lower.contains('pending') || lower.contains('processing') || lower.contains('submitted')) return 'Chờ duyệt';
    if (lower.contains('closed') || lower.contains('completed')) return 'Đã đóng';
    if (lower.contains('overdue') || lower.contains('failed')) return 'Quá hạn';
    return status;
  }

  Color _scheduleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return _C.green;
      case 'partial':
        return _C.orange;
      case 'overdue':
        return _C.red;
      default:
        return Colors.grey;
    }
  }

  String _scheduleStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Da tra';
      case 'partial':
        return 'Tra mot phan';
      case 'overdue':
        return 'Qua han';
      case 'unpaid':
        return 'Chua tra';
      default:
        return status;
    }
  }

  Widget _infoRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: _C.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: _C.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (!isLast) const Divider(height: 16, color: _C.border),
      ],
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _scheduleItem(LoanRepaymentScheduleItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ky ${item.installmentNo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _scheduleStatusColor(item.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _scheduleStatusText(item.status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _scheduleStatusColor(item.status)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Han: ${_formatDate(item.dueDate)}', style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
          const SizedBox(height: 6),
          Text('Tong phai tra: ${_formatCurrencyText(item.totalDue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _C.blue),
        ),
        title: const Text(
          'Chi tiết khoản vay',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Loi: $_error'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadDetail, child: const Text('Thu lai')),
                    ],
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('Khong co du lieu'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('So hieu: ${_detail!.code}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(_detail!.status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(_detail!.status),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(_detail!.status)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _formatCurrencyText(_detail!.approvedAmount),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text('So tien duyet', style: TextStyle(fontSize: 12, color: _C.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard('Thong tin khoan vay', [
                          _infoRow('So tien duyet', _formatCurrencyText(_detail!.approvedAmount)),
                          _infoRow('So tien giai ngan', _formatCurrencyText(_detail!.disbursedAmount)),
                          _infoRow('Lai suat thuc te', '${_detail!.actualInterestRate.toStringAsFixed(2)}%'),
                          _infoRow('Phuong phap tinh', _formatMethod(_detail!.interestCalculationMethod)),
                          _infoRow('Ky han', '${_detail!.termMonths} thang'),
                          _infoRow('Tan suat tra', _formatFrequency(_detail!.repaymentFrequency)),
                          _infoRow('Ngay giai ngan', _formatDate(_detail!.disbursedAt)),
                          _infoRow('Ngay tra tiep', _formatDate(_detail!.nextDueDate)),
                          _infoRow('Ngay dong', _formatDate(_detail!.closedAt), isLast: true),
                        ]),
                        const SizedBox(height: 12),
                        _sectionCard('Du no hien tai', [
                          _infoRow('Goc con lai', _formatCurrencyText(_detail!.outstandingPrincipal)),
                          _infoRow('Lai con lai', _formatCurrencyText(_detail!.outstandingInterest)),
                          _infoRow('Qua han goc', _formatCurrencyText(_detail!.overduePrincipal)),
                          _infoRow('Qua han lai', _formatCurrencyText(_detail!.overdueInterest), isLast: true),
                        ]),
                        const SizedBox(height: 12),
                        _sectionCard('Lich tra no', [
                          if (_detail!.schedule.isEmpty)
                            const Text('Chua co lich tra no', style: TextStyle(fontSize: 12, color: _C.textSecondary))
                          else ...[
                            ..._detail!.schedule.take(5).map(_scheduleItem),
                            if (_detail!.schedule.length > 5)
                              Text(
                                'Con ${_detail!.schedule.length - 5} ky nua',
                                style: const TextStyle(fontSize: 12, color: _C.textSecondary),
                              ),
                          ],
                        ]),
                      ],
                    ),
    );
  }
}
