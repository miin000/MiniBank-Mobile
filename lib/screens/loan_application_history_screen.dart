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
  static const green = Color(0xFF00C48C);
  static const orange = Color(0xFFFF6B35);
  static const blue = Color(0xFF2563EB);
  static const red = Color(0xFFEF4444);
}

class _FilterOption {
  final String label;
  final String? value; // null = all
  const _FilterOption(this.label, this.value);
}

class LoanApplicationHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const LoanApplicationHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<LoanApplicationHistoryScreen> createState() => _LoanApplicationHistoryScreenState();
}

class _LoanApplicationHistoryScreenState extends State<LoanApplicationHistoryScreen> {
  late LoanApi _loanApi;

  List<LoanApplication> _all = [];
  bool _loading = false;
  String? _error;
  String? _selectedFilter; // null = all

  final List<_FilterOption> _filters = const [
    _FilterOption('Tất cả', null),
    _FilterOption('Chờ duyệt', 'pending'),
    _FilterOption('Đã duyệt', 'approved'),
    _FilterOption('Chờ ký HĐ', 'pending_signature'),
    _FilterOption('Đang hoạt động', 'active'),
    _FilterOption('Từ chối', 'rejected'),
    _FilterOption('Đã đóng', 'closed'),
  ];

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await _loanApi.getMyApplications();
      apps.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (mounted) setState(() => _all = apps);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LoanApplication> get _filtered {
    if (_selectedFilter == null) return _all;
    return _all.where((a) {
      final s = a.status.toLowerCase();
      return switch (_selectedFilter) {
        'pending' => s == 'pending' || s == 'pending_approval' || s == 'submitted' || s == 'processing',
        'approved' => s == 'approved',
        'pending_signature' => s == 'pending_signature' || s == 'pending_contract' || s == 'pending_otp',
        'active' => s == 'active' || s == 'open',
        'rejected' => s == 'rejected' || s == 'cancelled',
        'closed' => s == 'closed' || s == 'completed',
        _ => true,
      };
    }).toList();
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open')) return _C.green;
    if (l.contains('approved')) return _C.blue;
    if (l.contains('pending') || l.contains('submitted') || l.contains('processing')) return _C.orange;
    if (l.contains('rejected') || l.contains('cancel')) return _C.red;
    if (l.contains('closed') || l.contains('completed')) return _C.textSecondary;
    return _C.textSecondary;
  }

  String _statusLabel(String s) {
    return switch (s.toLowerCase()) {
      'active' || 'open' => 'Đang hoạt động',
      'pending' || 'pending_approval' || 'submitted' || 'processing' => 'Chờ duyệt',
      'approved' => 'Đã duyệt',
      'pending_signature' || 'pending_contract' => 'Chờ ký HĐ',
      'pending_otp' => 'Chờ xác thực',
      'closed' || 'completed' => 'Đã đóng',
      'rejected' => 'Từ chối',
      'cancelled' => 'Đã huỷ',
      _ => s,
    };
  }

  String _fmtCurrency(Object? amount) {
    try {
      final n = amount is num ? amount.toDouble() : double.parse(amount.toString());
      final s = n.toStringAsFixed(0);
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return '${buf.toString()} ₫';
    } catch (_) {
      return amount?.toString() ?? '-';
    }
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Lịch sử đăng ký vay',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary, letterSpacing: -0.4),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _C.blue,
        child: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final selected = _selectedFilter == f.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? _C.blue : _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? _C.blue : _C.border),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _C.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: _C.border),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? _buildError()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _buildItem(_filtered[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(LoanApplication app) {
    final color = _statusColor(app.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.credit_score_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                app.loanProductName?.isNotEmpty == true ? app.loanProductName! : 'Hồ sơ vay #${app.id}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary),
              ),
              Text('Nộp ngày ${_fmtDate(app.submittedAt)}',
                  style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel(app.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _C.border),
        const SizedBox(height: 12),
        Row(children: [
          _infoChip(Icons.attach_money, _fmtCurrency(app.requestedAmount)),
          const SizedBox(width: 12),
          _infoChip(Icons.calendar_today_outlined, '${app.requestedTermMonths} tháng'),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 13, color: _C.textSecondary),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: _C.textSecondary, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_outlined, size: 40, color: _C.textSecondary),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.credit_card_off_outlined, size: 48, color: _C.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('Chưa có hồ sơ vay nào', style: TextStyle(fontSize: 14, color: _C.textSecondary)),
      ]),
    );
  }
}