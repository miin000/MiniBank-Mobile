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
  static const teal = Color(0xFF0D9488);
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

class _SavingDetailScreenState extends State<SavingDetailScreen>
    with SingleTickerProviderStateMixin {
  late SavingApi _savingApi;
  SavingDetail? _detail;
  bool _loading = false;
  String? _error;
  late TabController _tabController;

  bool _settlementSubmitted = false;
  bool _settlementLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _savingApi = SavingApi(api: api);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: BorderRadius.circular(10),
              ),
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

  // ─── Formatters ──────────────────────────────────────────────────────────

  String _fmtCurrency(double? v) {
    if (v == null) return '-';
    final n = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int c = 0;
    for (int i = n.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(n[i]);
      c++;
    }
    return '${buf.toString().split('').reversed.join()} VND';
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '-';
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return s;
    }
  }

  String _fmtTerm(String unit, int value) {
    return '$value ${unit.toUpperCase() == 'YEAR' ? 'năm' : 'tháng'}';
  }

  String _fmtRateType(String t) {
    switch (t.toUpperCase()) {
      case 'FIXED':
        return 'Cố định';
      case 'FLOATING':
        return 'Thả nổi';
      default:
        return t;
    }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open')) return _C.green;
    if (l.contains('pending') || l.contains('processing')) return _C.orange;
    if (l.contains('closed') || l.contains('completed')) return Colors.grey;
    if (l.contains('rejected') || l.contains('failed')) return _C.red;
    return _C.blue;
  }

  String _statusLabel(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open')) return 'Hoạt động';
    if (l.contains('pending') ||
        l.contains('processing') ||
        l.contains('submitted'))
      return 'Chờ duyệt';
    if (l.contains('closed') || l.contains('completed')) return 'Đã đóng';
    if (l.contains('rejected') || l.contains('failed')) return 'Từ chối';
    return s;
  }

  bool get _canRequestSettlement {
    if (_detail == null) return false;
    final l = _detail!.status.toLowerCase();
    return l.contains('active') || l.contains('open');
  }

  // ─── Interest timeline helpers ───────────────────────────────────────────

  /// Generate projected monthly interest accumulation timeline
  List<_MonthlyInterest> _buildTimeline() {
    final d = _detail!;
    if (d.openDate == null || d.maturityDate == null) return [];

    DateTime? open;
    DateTime? maturity;
    try {
      open = DateTime.parse(d.openDate!);
      maturity = DateTime.parse(d.maturityDate!);
    } catch (_) {
      return [];
    }

    // Annual rate — normalise to fraction
    double annualRate = d.actualInterestRate;
    if (annualRate > 1) annualRate = annualRate / 100;

    final monthlyRate = annualRate / 12;
    final principal = d.principalAmount;
    final months = d.termValue.clamp(1, 360);

    final List<_MonthlyInterest> result = [];
    double cumulative = 0;

    for (int i = 1; i <= months; i++) {
      final monthInterest = d.capitalized
          ? principal *
                monthlyRate *
                (1 + monthlyRate).pow(i - 1) // compound
          : principal * monthlyRate; // simple
      cumulative += monthInterest;

      final date = DateTime(open.year, open.month + i, open.day);
      result.add(
        _MonthlyInterest(
          month: i,
          date: date,
          interest: monthInterest,
          cumulative: cumulative,
          isPast: date.isBefore(DateTime.now()),
        ),
      );
    }
    return result;
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _infoRow(
    String label,
    String value, {
    bool isLast = false,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: _C.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? _C.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: _C.border),
      ],
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: _C.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _settlementBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.orange.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.orange.withOpacity(0.3)),
    ),
    child: const Row(
      children: [
        Icon(Icons.schedule_rounded, color: _C.orange, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Yêu cầu tất toán sớm đã được gửi và đang chờ nhân viên xét duyệt.',
            style: TextStyle(fontSize: 13, color: _C.orange),
          ),
        ),
      ],
    ),
  );

  Widget _settlementButton() {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ─── Tab: Thông tin ──────────────────────────────────────────────────────

  Widget _tabInfo() {
    final d = _detail!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_canRequestSettlement) ...[
          _settlementButton(),
          const SizedBox(height: 12),
        ],
        _card('Thông tin chính', [
          _infoRow('Sản phẩm', d.productName),
          _infoRow('Trạng thái', _statusLabel(d.status)),
          _infoRow('Số tiền gửi', _fmtCurrency(d.principalAmount)),
          _infoRow('Ngày mở', _fmtDate(d.openDate)),
          _infoRow('Ngày đáo hạn', _fmtDate(d.maturityDate)),
          _infoRow('Ngày đóng', _fmtDate(d.closeDate), isLast: true),
        ]),
        _card('Lãi và kỳ hạn', [
          _infoRow(
            'Lãi suất thực tế',
            '${d.actualInterestRate.toStringAsFixed(2)}%'
                '${d.actualInterestRate > 1 ? "/năm" : " (phân số)/năm"}',
          ),
          _infoRow('Hình thức lãi', _fmtRateType(d.interestRateType)),
          _infoRow('Kỳ hạn', _fmtTerm(d.termUnit, d.termValue)),
          _infoRow(
            'Lãi nhập gốc',
            d.capitalized ? 'Có (lãi kép)' : 'Không (lãi đơn)',
          ),
          _infoRow('Tự động tái tục', d.autoRenew ? 'Có' : 'Không'),
          _infoRow(
            'Lãi tích lũy',
            _fmtCurrency(d.accruedInterestAmount),
            valueColor: _C.teal,
          ),
          _infoRow('Lãi đã trả', _fmtCurrency(d.postedInterestAmount)),
          _infoRow(
            'Dự kiến đáo hạn',
            _fmtCurrency(d.projectedMaturityAmount),
            valueColor: _C.green,
            isLast: true,
          ),
        ]),
      ],
    );
  }

  // ─── Tab: Lãi hàng tháng ─────────────────────────────────────────────────

  Widget _tabInterest() {
    final d = _detail!;
    final timeline = _buildTimeline();

    if (timeline.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'Chưa đủ thông tin để tính lãi',
              style: TextStyle(color: _C.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Max cumulative for bar chart scaling
    final maxCumulative = timeline.last.cumulative;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lãi dự kiến đến đáo hạn',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                _fmtCurrency(
                  d.projectedMaturityAmount != null
                      ? d.projectedMaturityAmount! - d.principalAmount
                      : timeline.last.cumulative,
                ),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryChip('Gốc', _fmtCurrency(d.principalAmount)),
                  const SizedBox(width: 12),
                  _summaryChip(
                    'Lãi suất',
                    '${d.actualInterestRate.toStringAsFixed(d.actualInterestRate > 1 ? 1 : 4)}%/năm',
                  ),
                  const SizedBox(width: 12),
                  _summaryChip(
                    'Hình thức',
                    d.capitalized ? 'Lãi kép' : 'Lãi đơn',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Monthly breakdown
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Lãi cộng dồn hàng tháng',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1, color: _C.border),
              ...timeline.map((item) => _interestRow(item, maxCumulative)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _interestRow(_MonthlyInterest item, double maxCumulative) {
    final progress = maxCumulative > 0 ? item.cumulative / maxCumulative : 0.0;
    final now = DateTime.now();
    final isPast = item.date.isBefore(now);
    final isCurrent =
        item.date.year == now.year && item.date.month == now.month;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: isCurrent ? _C.teal.withOpacity(0.04) : null,
        border: Border(bottom: BorderSide(color: _C.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Month indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPast
                  ? _C.teal.withOpacity(0.12)
                  : isCurrent
                  ? _C.teal.withOpacity(0.2)
                  : _C.border,
            ),
            child: Center(
              child: Text(
                '${item.month}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPast || isCurrent ? _C.teal : _C.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmtDate(item.date.toIso8601String()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent ? _C.teal : _C.textSecondary,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${_fmtCurrency(item.interest)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isPast ? _C.teal : _C.textSecondary,
                          ),
                        ),
                        Text(
                          'Cộng dồn: ${_fmtCurrency(item.cumulative)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: _C.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    backgroundColor: _C.border,
                    valueColor: AlwaysStoppedAnimation(
                      isPast ? _C.teal : _C.teal.withOpacity(0.3),
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

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
            color: _C.textPrimary,
          ),
        ),
        bottom: _loading || _error != null || _detail == null
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: _C.blue,
                unselectedLabelColor: _C.textSecondary,
                indicatorColor: _C.blue,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Thông tin'),
                  Tab(text: 'Lãi hàng tháng'),
                ],
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
                  Text('Lỗi: $_error'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadDetail,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : _detail == null
          ? const Center(child: Text('Không có dữ liệu'))
          : Column(
              children: [
                _buildHeaderCard(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_tabInfo(), _tabInterest()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    final d = _detail!;
    final color = _statusColor(d.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              Text(
                'Số hiệu: ${d.code}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _C.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(d.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            d.productName,
            style: const TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            _fmtCurrency(d.principalAmount),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Số tiền gửi',
            style: TextStyle(fontSize: 12, color: _C.textSecondary),
          ),
          // Show projected maturity if available
          if (d.projectedMaturityAmount != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trending_up, size: 14, color: _C.teal),
                const SizedBox(width: 4),
                Text(
                  'Đáo hạn dự kiến: ${_fmtCurrency(d.projectedMaturityAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.teal,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Data model for timeline ─────────────────────────────────────────────────

class _MonthlyInterest {
  final int month;
  final DateTime date;
  final double interest;
  final double cumulative;
  final bool isPast;

  const _MonthlyInterest({
    required this.month,
    required this.date,
    required this.interest,
    required this.cumulative,
    required this.isPast,
  });
}

extension _NumPow on double {
  double pow(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) result *= this;
    return result;
  }
}
