import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/loan_api.dart';
import '../api/service_request_api.dart';
import '../auth/auth_storage.dart';

class _C {
  static const bg           = Color(0xFFF7F8FC);
  static const surface      = Colors.white;
  static const border       = Color(0xFFE8EAF0);
  static const textPrimary  = Color(0xFF0D1B3E);
  static const textSecondary= Color(0xFF6B7299);
  static const blue         = Color(0xFF2563EB);
  static const green        = Color(0xFF00A86B);
  static const orange       = Color(0xFFF97316);
  static const red          = Color(0xFFEF4444);
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

class _LoanDetailScreenState extends State<LoanDetailScreen>
    with SingleTickerProviderStateMixin {
  late LoanApi _loanApi;
  late ServiceRequestApi _serviceRequestApi;
  LoanDetail? _detail;
  bool _loading = false;
  bool _requestingEarlyPayment = false;
  bool _requestingInstallmentPayment = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
    _serviceRequestApi = ServiceRequestApi(api: api);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = null; });
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

  // ─── Formatters ──────────────────────────────────────────────────────────

  String _fmtCurrency(double? v) {
    if (v == null) return '-';
    // Format with thousand separators
    final n = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = n.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(n[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()} VND';
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '-';
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return s; }
  }

  String _fmtFrequency(String v) {
    switch (v.toUpperCase()) {
      case 'MONTHLY'   : return 'Hàng tháng';
      case 'WEEKLY'    : return 'Hàng tuần';
      case 'QUARTERLY' : return 'Hàng quý';
      case 'YEARLY'    : return 'Hàng năm';
      default          : return v;
    }
  }

  String _fmtMethod(String v) {
    switch (v.toUpperCase()) {
      case 'REDUCING_BALANCE': return 'Dư nợ giảm dần';
      case 'FLAT'            : return 'Lãi suất cố định';
      default                : return v;
    }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open'))          return _C.green;
    if (l.contains('pending') || l.contains('processing'))   return _C.orange;
    if (l.contains('closed') || l.contains('completed'))     return Colors.grey;
    if (l.contains('overdue') || l.contains('failed'))       return _C.red;
    return _C.blue;
  }

  String _statusLabel(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open'))          return 'Hoạt động';
    if (l.contains('pending') || l.contains('submitted'))    return 'Chờ duyệt';
    if (l.contains('closed') || l.contains('completed'))     return 'Đã đóng';
    if (l.contains('overdue'))                               return 'Quá hạn';
    return s;
  }

  Color _scheduleColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid'    : return _C.green;
      case 'partial' : return _C.orange;
      case 'overdue' : return _C.red;
      default        : return _C.textSecondary;
    }
  }

  String _scheduleLabel(String s) {
    switch (s.toLowerCase()) {
      case 'paid'    : return 'Đã trả';
      case 'partial' : return 'Trả 1 phần';
      case 'overdue' : return 'Quá hạn';
      case 'unpaid'  : return 'Chưa trả';
      default        : return s;
    }
  }

  bool _isDueThisMonth(LoanRepaymentScheduleItem item) {
    final due = DateTime.tryParse(item.dueDate);
    final now = DateTime.now();
    return due != null && due.year == now.year && due.month == now.month;
  }

  bool _canPaySchedule(LoanRepaymentScheduleItem item) {
    final status = item.status.toLowerCase();
    if (status == 'paid') return false;
    if (item.remainingDue <= 0) return false;
    final due = DateTime.tryParse(item.dueDate);
    if (due == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return !dueDay.isAfter(today);
  }

  Future<void> _requestInstallmentPayment(LoanRepaymentScheduleItem item) async {
    final d = _detail;
    if (d == null || _requestingInstallmentPayment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thanh toán kỳ ${item.installmentNo}?'),
        content: Text(
          'Gửi yêu cầu thanh toán ${_fmtCurrency(item.remainingDue)} cho kỳ hạn ngày ${_fmtDate(item.dueDate)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Thanh toán'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _requestingInstallmentPayment = true);
    try {
      await _serviceRequestApi.createServiceRequest(
        requestType: 'loan_installment_payment',
        title: 'Thanh toán kỳ ${item.installmentNo} khoản vay ${d.code}',
        description:
            'Khách hàng yêu cầu thanh toán kỳ ${item.installmentNo}, hạn ${item.dueDate}.',
        priorityTag: _isDueThisMonth(item) ? 'DUE_THIS_MONTH' : 'LOAN_PAYMENT',
        payloadJson:
            '{"loanId":${d.id},"loanCode":"${d.code}","scheduleId":${item.id},"installmentNo":${item.installmentNo},"amount":${item.remainingDue}}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu thanh toán kỳ trả nợ.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không gửi được yêu cầu: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingInstallmentPayment = false);
    }
  }

  Future<void> _requestEarlyLoanPayment() async {
    final d = _detail;
    if (d == null || _requestingEarlyPayment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thanh toán khoản vay trước hạn?'),
        content: Text(
          'Yêu cầu thanh toán sớm khoản vay ${d.code} sẽ được gửi lên admin web để chờ duyệt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _requestingEarlyPayment = true);
    try {
      await _serviceRequestApi.createServiceRequest(
        requestType: 'loan_early_payment',
        title: 'Yêu cầu thanh toán khoản vay trước hạn',
        description: 'Khách hàng yêu cầu thanh toán sớm khoản vay ${d.code}.',
        priorityTag: 'EARLY_LOAN_PAYMENT',
        payloadJson:
            '{"loanId":${d.id},"loanCode":"${d.code}","outstandingPrincipal":${d.outstandingPrincipal},"outstandingInterest":${d.outstandingInterest}}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu, vui lòng chờ admin duyệt.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không gửi được yêu cầu: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingEarlyPayment = false);
    }
  }

  // ─── Widget helpers ──────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {bool isLast = false, Color? valueColor}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        color: valueColor ?? _C.textPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, color: _C.border),
      ],
    );
  }

  Widget _card(String title, List<Widget> children, {Widget? trailing}) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.textPrimary)),
                if (trailing != null) trailing,
              ],
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

  // ─── Tab: Thông tin ──────────────────────────────────────────────────────

  Widget _tabInfo() {
    final d = _detail!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _card('Thông tin khoản vay', [
          _infoRow('Số tiền được duyệt', _fmtCurrency(d.approvedAmount)),
          _infoRow('Số tiền giải ngân', _fmtCurrency(d.disbursedAmount)),
          _infoRow('Lãi suất thực tế',
              '${d.actualInterestRate.toStringAsFixed(2)}%'
              '${d.actualInterestRate > 1 ? "/năm" : " (phân số)/năm"}'),
          _infoRow('Phương pháp tính', _fmtMethod(d.interestCalculationMethod)),
          _infoRow('Kỳ hạn', '${d.termMonths} tháng'),
          _infoRow('Tần suất trả', _fmtFrequency(d.repaymentFrequency)),
          _infoRow('Ngày giải ngân', _fmtDate(d.disbursedAt)),
          _infoRow('Kỳ trả tiếp theo', _fmtDate(d.nextDueDate)),
          _infoRow('Ngày đóng', _fmtDate(d.closedAt), isLast: true),
        ]),
        _card('Dư nợ hiện tại', [
          _infoRow('Gốc còn lại', _fmtCurrency(d.outstandingPrincipal)),
          _infoRow('Lãi còn lại', _fmtCurrency(d.outstandingInterest)),
          _infoRow('Gốc quá hạn', _fmtCurrency(d.overduePrincipal),
              valueColor: d.overduePrincipal > 0 ? _C.red : null),
          _infoRow('Lãi quá hạn', _fmtCurrency(d.overdueInterest),
              valueColor: d.overdueInterest > 0 ? _C.red : null,
              isLast: true),
        ]),
        if (d.status.toLowerCase().contains('active') || d.status.toLowerCase().contains('open'))
          OutlinedButton(
            onPressed: _requestingEarlyPayment ? null : _requestEarlyLoanPayment,
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.orange,
              side: const BorderSide(color: _C.orange),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _requestingEarlyPayment
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Thanh toán trước hạn'),
          ),
      ],
    );
  }

  // ─── Tab: Lịch trả nợ ────────────────────────────────────────────────────

  Widget _tabSchedule() {
    final d = _detail!;
    if (d.schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Chưa có lịch trả nợ',
                style: TextStyle(color: _C.textSecondary, fontSize: 14)),
            const SizedBox(height: 6),
            const Text(
              'Lịch trả nợ sẽ được tạo sau khi\nhợp đồng vay được ký.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final paid    = d.schedule.where((s) => s.status.toLowerCase() == 'paid').length;
    final overdue = d.schedule.where((s) => s.status.toLowerCase() == 'overdue').length;
    final dueThisMonth = d.schedule.where((s) => _isDueThisMonth(s) && _canPaySchedule(s)).length;
    final total   = d.schedule.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _schedStat('Tổng kỳ', '$total', Colors.white),
              _schedDivider(),
              _schedStat('Đã trả', '$paid', const Color(0xFF86EFAC)),
              _schedDivider(),
              _schedStat('Quá hạn', '$overdue',
                  overdue > 0 ? const Color(0xFFFCA5A5) : Colors.white70),
              _schedDivider(),
              _schedStat('Đến tháng', '$dueThisMonth',
                  dueThisMonth > 0 ? const Color(0xFFFCA5A5) : Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Schedule items
        ...d.schedule.map((item) => _scheduleCard(item)),
      ],
    );
  }

  Widget _schedStat(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    ),
  );

  Widget _schedDivider() => Container(
    width: 1, height: 36,
    color: Colors.white.withValues(alpha: 0.2),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );

  Widget _scheduleCard(LoanRepaymentScheduleItem item) {
    final isPaid    = item.status.toLowerCase() == 'paid';
    final isOverdue = item.status.toLowerCase() == 'overdue';
    final isDueThisMonth = _isDueThisMonth(item) && !isPaid;
    final color     = _scheduleColor(item.status);
    final badgeColor = isOverdue || isDueThisMonth ? _C.red : color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? _C.red.withValues(alpha: 0.4) : _C.border,
          width: isOverdue || isDueThisMonth ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${item.installmentNo}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: badgeColor)),
            ),
          ),
          title: Text(
            'Kỳ ${item.installmentNo} — ${_fmtDate(item.dueDate)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.textPrimary),
          ),
          subtitle: Row(
            children: [
              Text(_fmtCurrency(item.totalDue),
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_scheduleLabel(item.status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
              if (isDueThisMonth) ...[
                const SizedBox(width: 6),
                const Icon(Icons.circle, size: 9, color: _C.red),
              ],
            ],
          ),
          children: [
            const Divider(height: 1, color: _C.border),
            const SizedBox(height: 10),
            _schedRow('Dư nợ đầu kỳ', _fmtCurrency(item.openingPrincipalBalance)),
            _schedRow('Gốc phải trả', _fmtCurrency(item.principalDue)),
            _schedRow('Lãi suất kỳ này',
                '${(item.interestRate > 1 ? item.interestRate : item.interestRate * 100).toStringAsFixed(4)}%/năm'),
            _schedRow('Lãi phải trả', _fmtCurrency(item.interestDue)),
            if (item.penaltyInterestDue > 0)
              _schedRow('Lãi phạt', _fmtCurrency(item.penaltyInterestDue),
                  valueColor: _C.red),
            if (item.feeDue > 0)
              _schedRow('Phí', _fmtCurrency(item.feeDue)),
            const Divider(height: 16, color: _C.border),
            _schedRow('Tổng phải trả', _fmtCurrency(item.totalDue),
                bold: true),
            _schedRow('Còn phải trả', _fmtCurrency(item.remainingDue),
                bold: true, valueColor: _canPaySchedule(item) ? _C.red : _C.green),
            if (isPaid) ...[
              _schedRow('Gốc đã trả', _fmtCurrency(item.principalPaid)),
              _schedRow('Lãi đã trả', _fmtCurrency(item.interestPaid)),
              if (item.paidAt != null)
                _schedRow('Ngày thanh toán', _fmtDate(item.paidAt)),
            ],
            if (_canPaySchedule(item)) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestingInstallmentPayment
                      ? null
                      : () => _requestInstallmentPayment(item),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: Text(
                    _requestingInstallmentPayment ? 'Đang gửi...' : 'Thanh toán kỳ này',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverdue || isDueThisMonth ? _C.red : _C.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (!isPaid && !isOverdue) ...[
              const SizedBox(height: 10),
              Text(
                _isDueThisMonth(item) ? 'Đến hạn tháng này' : 'Chưa đến hạn',
                style: const TextStyle(fontSize: 11, color: _C.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _schedRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor ?? _C.textPrimary)),
        ],
      ),
    );
  }

  // ─── Tab: Hợp đồng ──────────────────────────────────────────────────────

  Widget _tabContracts() {
    return _ContractTab(
      baseUrl: widget.baseUrl,
      storage: widget.storage,
      loanApi: _loanApi,
      loanApplicationId: _detail?.loanApplicationId,
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
        title: const Text('Chi tiết khoản vay',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary)),
        bottom: _loading || _error != null || _detail == null
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: _C.blue,
                unselectedLabelColor: _C.textSecondary,
                indicatorColor: _C.blue,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Thông tin'),
                  Tab(text: 'Lịch trả nợ'),
                  Tab(text: 'Hợp đồng'),
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
                      ElevatedButton(onPressed: _loadDetail, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('Không có dữ liệu'))
                  : Column(
                      children: [
                        // Header card
                        _buildHeaderCard(),
                        // Tabs
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _tabInfo(),
                              _tabSchedule(),
                              _tabContracts(),
                            ],
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
              Text('Số hiệu: ${d.code}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _C.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_statusLabel(d.status),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_fmtCurrency(d.approvedAmount),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.textPrimary)),
          const SizedBox(height: 2),
          const Text('Số tiền được duyệt',
              style: TextStyle(fontSize: 12, color: _C.textSecondary)),
          const SizedBox(height: 12),
          // Progress bar: principal repaid
          if (d.approvedAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Đã trả gốc',
                    style: TextStyle(fontSize: 11, color: _C.textSecondary)),
                Text(
                  '${((d.approvedAmount - d.outstandingPrincipal) / d.approvedAmount * 100).clamp(0, 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.blue),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((d.approvedAmount - d.outstandingPrincipal) / d.approvedAmount).clamp(0, 1),
                backgroundColor: _C.border,
                valueColor: const AlwaysStoppedAnimation(_C.blue),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Contract Tab Widget ──────────────────────────────────────────────────────

class _ContractTab extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final LoanApi loanApi;
  final int? loanApplicationId;

  const _ContractTab({
    required this.baseUrl,
    required this.storage,
    required this.loanApi,
    this.loanApplicationId,
  });

  @override
  State<_ContractTab> createState() => _ContractTabState();
}

class _ContractTabState extends State<_ContractTab> {
  List<LoanContract>? _contracts;
  bool _loading = false;
  String? _error;
  final Set<int> _signing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await widget.loanApi.getMyContracts();
      // Filter to loan_application contracts matching this loan's application
      final filtered = widget.loanApplicationId != null
          ? all.where((c) =>
              c.ownerType == 'loan_application' &&
              c.ownerId == widget.loanApplicationId).toList()
          : all.where((c) => c.ownerType == 'loan_application').toList();
      if (!mounted) return;
      setState(() => _contracts = filtered);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sign(LoanContract contract) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ký hợp đồng',
            style: TextStyle(fontWeight: FontWeight.w700, color: _C.textPrimary)),
        content: Text(
          'Xác nhận ký hợp đồng ${contract.contractNumber ?? "#${contract.id}"}?\n\n'
          'Sau khi ký, khoản vay sẽ được giải ngân vào tài khoản của bạn.',
          style: const TextStyle(fontSize: 14, color: _C.textSecondary),
        ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ký hợp đồng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signing.add(contract.id));
    try {
      await widget.loanApi.signContract(contract.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hợp đồng đã được ký. Khoản vay đã giải ngân!'),
          backgroundColor: _C.green,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: _C.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _signing.remove(contract.id));
    }
  }

  String _contractStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'signed'            : return 'Đã ký';
      case 'pending_signature' :
      case 'pending'           :
      case 'sent'              :
      case 'draft'             : return 'Chờ ký';
      default                  : return s;
    }
  }

  Color _contractStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'signed'            : return _C.green;
      case 'pending_signature' :
      case 'pending'           :
      case 'sent'              :
      case 'draft'             : return _C.orange;
      default                  : return _C.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: _C.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Chưa có hợp đồng',
                style: TextStyle(color: _C.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contracts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = contracts[i];
        final statusColor = _contractStatusColor(c.status);
        final isSigning = _signing.contains(c.id);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.contractNumber ?? 'Hợp đồng #${c.id}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_contractStatusLabel(c.status),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Ngày tạo: ${_fmtDate(c.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
              if (c.signedAt != null)
                Text('Ngày ký: ${_fmtDate(c.signedAt)}',
                    style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
              if (c.renderedBody != null && c.renderedBody!.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(c.contractNumber ?? 'Hợp đồng #${c.id}'),
                      content: SingleChildScrollView(
                        child: Text(c.renderedBody!, style: const TextStyle(fontSize: 13)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Xem nội dung hợp đồng'),
                ),
              ],
              if (c.canSign) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSigning ? null : () => _sign(c),
                    icon: isSigning
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.edit_document, size: 16),
                    label: Text(isSigning ? 'Đang ký...' : 'Ký hợp đồng'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '-';
    try {
      final d = DateTime.parse(s);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return s; }
  }
}