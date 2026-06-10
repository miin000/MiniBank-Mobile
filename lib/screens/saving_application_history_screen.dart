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
  static const green = Color(0xFF00C48C);
  static const orange = Color(0xFFFF6B35);
  static const blue = Color(0xFF2563EB);
  static const red = Color(0xFFEF4444);
}

class _FilterOption {
  final String label;
  final String? value;
  const _FilterOption(this.label, this.value);
}

class SavingApplicationHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const SavingApplicationHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<SavingApplicationHistoryScreen> createState() => _SavingApplicationHistoryScreenState();
}

class _SavingApplicationHistoryScreenState extends State<SavingApplicationHistoryScreen> {
  late SavingApi _savingApi;

  List<dynamic> _all = [];
  bool _loading = false;
  String? _error;
  String? _selectedFilter;

  final List<_FilterOption> _filters = const [
    _FilterOption('Tất cả', null),
    _FilterOption('Chờ duyệt', 'pending'),
    _FilterOption('Chờ xác thực', 'pending_otp'),
    _FilterOption('Đang hoạt động', 'active'),
    _FilterOption('Đã tất toán', 'closed'),
    _FilterOption('Từ chối', 'rejected'),
  ];

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _savingApi = SavingApi(api: api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final savings = await _savingApi.getSavings();
      savings.sort((a, b) {
        final aDate = _safeStr(() => a.openDate) ?? '';
        final bDate = _safeStr(() => b.openDate) ?? '';
        return bDate.compareTo(aDate);
      });
      if (mounted) setState(() => _all = savings);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _safeStr(String? Function() fn) {
    try { return fn(); } catch (_) { return null; }
  }

  Object? _safeVal(Object? Function() fn) {
    try { return fn(); } catch (_) { return null; }
  }

  List<dynamic> get _filtered {
    if (_selectedFilter == null) return _all;
    return _all.where((s) {
      final status = (_safeVal(() => s.status) ?? '').toString().toLowerCase();
      return switch (_selectedFilter) {
        'pending' => status == 'pending' || status == 'pending_approval' || status == 'submitted' || status == 'processing',
        'pending_otp' => status == 'pending_otp',
        'active' => status == 'active' || status == 'open',
        'closed' => status == 'closed' || status == 'completed' || status == 'matured',
        'rejected' => status == 'rejected' || status == 'cancelled',
        _ => true,
      };
    }).toList();
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l == 'active' || l == 'open') return _C.green;
    if (l == 'approved') return _C.blue;
    if (l.contains('pending') || l.contains('submitted') || l.contains('processing')) return _C.orange;
    if (l.contains('rejected') || l.contains('cancel')) return _C.red;
    if (l == 'closed' || l == 'completed' || l == 'matured') return _C.textSecondary;
    return _C.textSecondary;
  }

  String _statusLabel(String s) {
    return switch (s.toLowerCase()) {
      'active' || 'open' => 'Đang hoạt động',
      'pending' || 'pending_approval' || 'submitted' || 'processing' => 'Chờ duyệt',
      'pending_otp' => 'Chờ xác thực OTP',
      'closed' => 'Đã đóng',
      'completed' || 'matured' => 'Đã tất toán',
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
          'Lịch sử mở sổ tiết kiệm',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary, letterSpacing: -0.4),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _C.green,
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
                        color: selected ? _C.green : _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? _C.green : _C.border),
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
            // Count label
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Text(
                  '${_filtered.length} sổ tiết kiệm',
                  style: const TextStyle(fontSize: 12, color: _C.textSecondary, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
            const Divider(height: 1, color: _C.border),
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

  Widget _buildItem(dynamic saving) {
    final status = (_safeVal(() => saving.status) ?? '').toString();
    final color = _statusColor(status);
    final code = _safeVal(() => saving.code)?.toString();
    final productName = _safeVal(() => saving.productName)?.toString();
    final principal = _safeVal(() => saving.principalAmount);
    final interestRate = _safeVal(() => saving.interestRate);
    final termMonths = _safeVal(() => saving.termMonths);
    final createdAt = _safeStr(() => saving.openDate?.toString());
    final maturityDate = _safeStr(() => saving.maturityDate?.toString());

    final title = code != null && code.isNotEmpty
        ? 'Sổ tiết kiệm $code'
        : productName != null && productName.isNotEmpty
            ? productName
            : 'Sổ tiết kiệm';

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
            child: Icon(Icons.savings_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
              Text('Tạo ngày ${_fmtDate(createdAt)}',
                  style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _C.border),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 6, children: [
          if (principal != null) _infoChip(Icons.attach_money, _fmtCurrency(principal)),
          if (interestRate != null) _infoChip(Icons.percent, '$interestRate%/năm'),
          if (termMonths != null) _infoChip(Icons.calendar_today_outlined, '$termMonths tháng'),
          if (maturityDate != null && maturityDate.isNotEmpty)
            _infoChip(Icons.event_available_outlined, 'Đáo hạn ${_fmtDate(maturityDate)}'),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
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
        Icon(Icons.savings_outlined, size: 48, color: _C.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('Chưa có sổ tiết kiệm nào', style: TextStyle(fontSize: 14, color: _C.textSecondary)),
      ]),
    );
  }
}