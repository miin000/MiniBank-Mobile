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

  /// Whether a settlement request has already been submitted this session.
  bool _settlementSubmitted = false;
  bool _settlementLoading = false;

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

  // ─── Early settlement ────────────────────────────────────────────────────

  Future<void> _requestEarlySettlement() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Yêu cầu tất toán sớm',
          style: TextStyle(fontWeight: FontWeight.w700, color: _C.textPrimary),
        ),
        content: const Text(
          'Bạn có chắc muốn gửi yêu cầu tất toán sớm sổ tiết kiệm này?\n\n'
          'Lãi suất có thể bị áp dụng theo tỷ lệ không kỳ hạn. '
          'Yêu cầu sẽ chờ nhân viên xét duyệt trước khi thực hiện.',
          style: TextStyle(fontSize: 14, color: _C.textSecondary),
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
              backgroundColor: _C.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _settlementLoading = true);
    try {
      await _savingApi.requestEarlySettlement(savingId: widget.savingId);
      if (!mounted) return;
      setState(() => _settlementSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yêu cầu tất toán đã được gửi. Vui lòng chờ duyệt.'),
          backgroundColor: _C.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: _C.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _settlementLoading = false);
    }
  }

  // ─── Formatting helpers ──────────────────────────────────────────────────

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
    final label = u == 'YEAR' ? 'năm' : 'tháng';
    return '$value $label';
  }

  String _formatRateType(String type) {
    switch (type.toUpperCase()) {
      case 'FIXED':
        return 'Cố định';
      case 'FLOATING':
        return 'Thả nổi';
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

  String _statusLabel(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('active') || lower.contains('open')) return 'Hoạt động';
    if (lower.contains('pending') || lower.contains('processing') ||
        lower.contains('submitted')) return 'Chờ duyệt';
    if (lower.contains('closed') || lower.contains('completed')) return 'Đã đóng';
    if (lower.contains('rejected') || lower.contains('failed')) return 'Từ chối';
    return status;
  }

  bool get _canRequestSettlement {
    if (_detail == null) return false;
    final lower = _detail!.status.toLowerCase();
    return lower.contains('active') || lower.contains('open');
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

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
                style: const TextStyle(
                    fontSize: 13,
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w600),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _settlementBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _C.orange, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Yêu cầu tất toán sớm đã được gửi và đang chờ nhân viên xét duyệt.',
              style: TextStyle(fontSize: 13, color: _C.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earlySettlementButton() {
    if (_settlementSubmitted) return _settlementBanner();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _settlementLoading ? null : _requestEarlySettlement,
        icon: _settlementLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.red),
              )
            : const Icon(Icons.exit_to_app_rounded, size: 18),
        label: const Text('Yêu cầu tất toán sớm'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.red,
          side: BorderSide(color: _C.red.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
          'Chi tiết sổ tiết kiệm',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary),
        ),
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
                          onPressed: _loadDetail,
                          child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('Không có dữ liệu'))
                  : ListView(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // ── Header card ──────────────────────────────────
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Số hiệu: ${_detail!.code}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(_detail!.status)
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(_detail!.status),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(
                                              _detail!.status)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _detail!.productName,
                                style: const TextStyle(
                                    fontSize: 12, color: _C.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _formatCurrencyText(_detail!.principalAmount),
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: _C.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Số tiền gửi',
                                style: TextStyle(
                                    fontSize: 12, color: _C.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Early settlement button (active only) ────────
                        if (_canRequestSettlement) ...[
                          _earlySettlementButton(),
                          const SizedBox(height: 16),
                        ],

                        // ── Main info ────────────────────────────────────
                        _sectionCard('Thông tin chính', [
                          _infoRow('Sản phẩm', _detail!.productName),
                          _infoRow('Trạng thái', _statusLabel(_detail!.status)),
                          _infoRow('Số tiền gửi',
                              _formatCurrencyText(_detail!.principalAmount)),
                          _infoRow('Ngày mở', _formatDate(_detail!.openDate)),
                          _infoRow('Ngày đáo hạn',
                              _formatDate(_detail!.maturityDate)),
                          _infoRow('Ngày đóng',
                              _formatDate(_detail!.closeDate),
                              isLast: true),
                        ]),
                        const SizedBox(height: 12),

                        // ── Interest info ────────────────────────────────
                        _sectionCard('Lãi và kỳ hạn', [
                          _infoRow('Lãi suất thực tế',
                              '${_detail!.actualInterestRate.toStringAsFixed(2)}%'),
                          _infoRow('Hình thức lãi',
                              _formatRateType(_detail!.interestRateType)),
                          _infoRow('Kỳ hạn',
                              _formatTerm(_detail!.termUnit, _detail!.termValue)),
                          _infoRow('Lãi nhập gốc',
                              _detail!.capitalized ? 'Có' : 'Không'),
                          _infoRow('Tự động tái tục',
                              _detail!.autoRenew ? 'Có' : 'Không'),
                          _infoRow('Lãi tích lũy',
                              _formatCurrencyText(
                                  _detail!.accruedInterestAmount)),
                          _infoRow('Lãi đã trả',
                              _formatCurrencyText(
                                  _detail!.postedInterestAmount)),
                          _infoRow('Dự kiến đáo hạn',
                              _formatCurrencyText(
                                  _detail!.projectedMaturityAmount),
                              isLast: true),
                        ]),
                      ],
                    ),
    );
  }
}