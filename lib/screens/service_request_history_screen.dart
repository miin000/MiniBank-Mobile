import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/service_request_api.dart';
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
  static const purple = Color(0xFF7C3AED);
  static const red = Color(0xFFEF4444);
}

class _FilterOption {
  final String label;
  final String? value;
  const _FilterOption(this.label, this.value);
}

class ServiceRequestHistoryScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const ServiceRequestHistoryScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<ServiceRequestHistoryScreen> createState() => _ServiceRequestHistoryScreenState();
}

class _ServiceRequestHistoryScreenState extends State<ServiceRequestHistoryScreen> {
  late ServiceRequestApi _serviceRequestApi;

  List<ServiceRequest> _all = [];
  bool _loading = false;
  String? _error;
  String? _selectedFilter;
  String? _selectedType;

  final List<_FilterOption> _statusFilters = const [
    _FilterOption('Tất cả', null),
    _FilterOption('Đang xử lý', 'pending'),
    _FilterOption('Đã duyệt', 'approved'),
    _FilterOption('Từ chối', 'rejected'),
    _FilterOption('Hoàn thành', 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _serviceRequestApi = ServiceRequestApi(api: api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _serviceRequestApi.getServiceRequests();
      requests.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (mounted) setState(() => _all = requests);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _requestTypes {
    final types = _all.map((r) => r.requestType).toSet().toList();
    types.sort();
    return types;
  }

  List<ServiceRequest> get _filtered {
    return _all.where((r) {
      // status filter
      if (_selectedFilter != null) {
        final s = r.status.toLowerCase();
        final pass = switch (_selectedFilter) {
          'pending' => s == 'pending' || s == 'pending_approval' || s == 'submitted' || s == 'processing',
          'approved' => s == 'approved',
          'rejected' => s == 'rejected' || s == 'cancelled',
          'completed' => s == 'completed' || s == 'closed' || s == 'done',
          _ => true,
        };
        if (!pass) return false;
      }
      // type filter
      if (_selectedType != null && r.requestType != _selectedType) return false;
      return true;
    }).toList();
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l == 'approved' || l == 'completed' || l == 'done' || l == 'closed') return _C.green;
    if (l.contains('pending') || l.contains('submitted') || l.contains('processing')) return _C.orange;
    if (l.contains('rejected') || l.contains('cancel')) return _C.red;
    return _C.textSecondary;
  }

  String _statusLabel(String s) {
    return switch (s.toLowerCase()) {
      'pending' || 'pending_approval' || 'submitted' || 'processing' => 'Đang xử lý',
      'approved' => 'Đã duyệt',
      'completed' || 'done' || 'closed' => 'Hoàn thành',
      'rejected' => 'Từ chối',
      'cancelled' => 'Đã huỷ',
      _ => s,
    };
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

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('limit') || t.contains('hạn mức')) return Icons.trending_up;
    if (t.contains('profile') || t.contains('thông tin')) return Icons.edit_note;
    if (t.contains('card') || t.contains('thẻ')) return Icons.credit_card_outlined;
    if (t.contains('account') || t.contains('tài khoản')) return Icons.account_circle_outlined;
    return Icons.assignment_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final types = _requestTypes;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Lịch sử yêu cầu dịch vụ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary, letterSpacing: -0.4),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _C.purple,
        child: Column(
          children: [
            // Status filter chips
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _statusFilters[i];
                  final selected = _selectedFilter == f.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? _C.purple : _C.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? _C.purple : _C.border),
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
            // Type filter (only show if there are multiple types)
            if (types.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: types.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final isAll = i == 0;
                    final type = isAll ? null : types[i - 1];
                    final label = isAll ? 'Tất cả loại' : type!;
                    final selected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? _C.blue.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? _C.blue.withValues(alpha: 0.4) : _C.border),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? _C.blue : _C.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(children: [
                Text(
                  '${_filtered.length} yêu cầu',
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

  Widget _buildItem(ServiceRequest req) {
    final color = _statusColor(req.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _C.purple.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(_typeIcon(req.requestType), color: _C.purple, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(req.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(req.requestType, style: const TextStyle(fontSize: 11, color: _C.textSecondary, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel(req.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        if (req.description != null && req.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(req.description!, style: const TextStyle(fontSize: 12, color: _C.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.access_time, size: 12, color: _C.textSecondary),
          const SizedBox(width: 4),
          Text(_fmtDate(req.submittedAt), style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
        ]),
        if (req.processNote != null && req.processNote!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _C.blue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 14, color: _C.blue),
              const SizedBox(width: 6),
              Expanded(child: Text(req.processNote!, style: const TextStyle(fontSize: 12, color: _C.blue))),
            ]),
          ),
        ],
      ]),
    );
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
        Icon(Icons.inbox_outlined, size: 48, color: _C.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('Chưa có yêu cầu dịch vụ nào', style: TextStyle(fontSize: 14, color: _C.textSecondary)),
      ]),
    );
  }
}