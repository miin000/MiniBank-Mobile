import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/saving_api.dart';
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

class SavingDetailScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final int savingId;

  const SavingDetailScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.savingId,
  });

  @override
  State<SavingDetailScreen> createState() => _SavingDetailScreenState();
}

class _SavingDetailScreenState extends State<SavingDetailScreen> {
  late SavingApi _savingApi;
  SavingDetail? _detail;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _savingApi = SavingApi(api: api);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _savingApi.getSavingById(widget.savingId);
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

  String _formatTerm(String unit, int value) {
    final u = unit.toUpperCase();
    final label = u == 'YEAR' ? 'nam' : 'thang';
    return '$value $label';
  }

  String _formatRateType(String type) {
    switch (type.toUpperCase()) {
      case 'FIXED':
        return 'Co dinh';
      case 'FLOATING':
        return 'Tha noi';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('active') || lower.contains('open')) return _C.green;
    if (lower.contains('pending') || lower.contains('processing')) return _C.orange;
    if (lower.contains('closed') || lower.contains('completed')) return Colors.grey;
    if (lower.contains('rejected') || lower.contains('failed')) return _C.red;
    return _C.blue;
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
          'Chi tiet so tiet kiem',
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
                                      _detail!.status,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(_detail!.status)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(_detail!.productName, style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
                              const SizedBox(height: 14),
                              Text(
                                _formatCurrencyText(_detail!.principalAmount),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text('So tien gui', style: TextStyle(fontSize: 12, color: _C.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionCard('Thong tin chinh', [
                          _infoRow('San pham', _detail!.productName),
                          _infoRow('Trang thai', _detail!.status),
                          _infoRow('So tien gui', _formatCurrencyText(_detail!.principalAmount)),
                          _infoRow('Ngay mo', _formatDate(_detail!.openDate)),
                          _infoRow('Ngay dao han', _formatDate(_detail!.maturityDate)),
                          _infoRow('Ngay dong', _formatDate(_detail!.closeDate), isLast: true),
                        ]),
                        const SizedBox(height: 12),
                        _sectionCard('Lai va ky han', [
                          _infoRow('Lai suat thuc te', '${_detail!.actualInterestRate.toStringAsFixed(2)}%'),
                          _infoRow('Hinh thuc lai', _formatRateType(_detail!.interestRateType)),
                          _infoRow('Ky han', _formatTerm(_detail!.termUnit, _detail!.termValue)),
                          _infoRow('Lai nhap goc', _detail!.capitalized ? 'Co' : 'Khong'),
                          _infoRow('Tu dong tai tuc', _detail!.autoRenew ? 'Co' : 'Khong'),
                          _infoRow('Lai tich luy', _formatCurrencyText(_detail!.accruedInterestAmount)),
                          _infoRow('Lai da tra', _formatCurrencyText(_detail!.postedInterestAmount)),
                          _infoRow('Du kien dao han', _formatCurrencyText(_detail!.projectedMaturityAmount), isLast: true),
                        ]),
                      ],
                    ),
    );
  }
}
