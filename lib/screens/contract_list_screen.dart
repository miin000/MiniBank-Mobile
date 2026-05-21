import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/authed_api.dart';
import '../api/contract_api.dart';
import '../auth/auth_storage.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF7F8FC);
  static const surface     = Colors.white;
  static const border      = Color(0xFFE8EAF0);
  static const primary     = Color(0xFF0D1B3E);
  static const secondary   = Color(0xFF6B7299);
  static const blue        = Color(0xFF185FA5);
  static const blueLight   = Color(0xFFE6F1FB);
  static const green       = Color(0xFF1D9E75);
  static const greenLight  = Color(0xFFE1F5EE);
  static const amber       = Color(0xFFBA7517);
  static const amberLight  = Color(0xFFFAEEDA);
  static const error       = Color(0xFFEF4444);
  static const errorLight  = Color(0xFFFEF2F2);
  static const grey        = Color(0xFF9CA3AF);
  static const greyLight   = Color(0xFFF3F4F6);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ContractListScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const ContractListScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen>
    with SingleTickerProviderStateMixin {
  late ContractApi _contractApi;
  late TabController _tabCtrl;

  List<ContractItem> _allItems   = [];
  bool   _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _contractApi = ContractApi(
      api: AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage),
    );
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── Data ────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _contractApi.getContracts();
      if (mounted) setState(() => _allItems = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ContractItem> get _loanItems =>
      _allItems.where((c) => c.isLoanContract).toList();

  List<ContractItem> get _savingItems =>
      _allItems.where((c) => c.isSavingCertificate).toList();

  // ─── Actions ─────────────────────────────────────────────────────────────
  Future<void> _openPdf(ContractItem item) async {
    if (item.fileUrl == null || item.fileUrl!.isEmpty) {
      _snack('Chưa có file hợp đồng', isError: true);
      return;
    }
    final uri = Uri.parse(item.fileUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Không thể mở file', isError: true);
    }
  }

  Future<void> _confirmSign(ContractItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận ký hợp đồng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'Bạn xác nhận đã đọc kỹ hợp đồng và đồng ý với tất cả điều khoản.\n\n'
          'Chữ ký điện tử sẽ được tạo bằng khoá bí mật của thiết bị.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ', style: TextStyle(color: _C.secondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _C.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ký xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doSign(item);
  }

  Future<void> _doSign(ContractItem item) async {
    // TODO: replace placeholder with real RSA signing from device key store
    const demoSignature = 'DEMO_RSA_SIGNATURE_BASE64';
    try {
      final updated = await _contractApi.signContract(item.id,
          digitalSignature: demoSignature);
      if (!mounted) return;
      setState(() {
        final idx = _allItems.indexWhere((c) => c.id == item.id);
        if (idx >= 0) _allItems[idx] = updated;
      });
      _snack('Ký hợp đồng thành công!');
    } catch (e) {
      if (!mounted) return;
      _snack('Lỗi ký hợp đồng: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _C.error : _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _C.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Hợp đồng & Chứng nhận',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.primary),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _C.blue,
          labelColor: _C.blue,
          unselectedLabelColor: _C.secondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Tất cả (${_allItems.length})'),
            Tab(text: 'Vay vốn (${_loanItems.length})'),
            Tab(text: 'Tiết kiệm (${_savingItems.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(_allItems),
                    _buildList(_loanItems),
                    _buildList(_savingItems),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_outlined, size: 48, color: _C.secondary),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center,
            style: const TextStyle(color: _C.secondary, fontSize: 13)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      ]),
    ),
  );

  Widget _buildList(List<ContractItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.description_outlined, size: 48, color: _C.secondary),
          const SizedBox(height: 10),
          const Text('Chưa có hợp đồng nào',
              style: TextStyle(color: _C.secondary, fontSize: 13)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(ContractItem c) {
    final isLoan = c.isLoanContract;
    final accent = isLoan ? _C.blue : _C.green;
    final accentLight = isLoan ? _C.blueLight : _C.greenLight;

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: accentLight, borderRadius: BorderRadius.circular(10)),
              child: Icon(
                isLoan ? Icons.account_balance_outlined : Icons.savings_outlined,
                size: 20, color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                c.contractNumber?.isNotEmpty == true
                    ? c.contractNumber!
                    : (isLoan ? 'Hợp đồng tín dụng' : 'Chứng nhận tiết kiệm'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.primary),
              ),
              const SizedBox(height: 2),
              Text(_ownerLabel(c),
                  style: const TextStyle(fontSize: 11, color: _C.secondary)),
            ])),
            _statusBadge(c),
          ]),
        ),

        Divider(height: 1, color: _C.border.withValues(alpha: 0.6)),

        // ── Info rows ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(children: [
            _infoRow(Icons.tag_rounded,       'Mã giao dịch',  '#${c.ownerId}'),
            _infoRow(Icons.insert_drive_file_outlined, 'Loại',
                isLoan ? 'Hợp đồng vay vốn' : 'Chứng nhận tiết kiệm'),
            _infoRow(Icons.schedule_rounded,  'Ngày tạo',      _fmtDate(c.createdAt)),
            if (c.signedAt != null)
              _infoRow(Icons.draw_outlined,   'Ngày ký',       _fmtDate(c.signedAt!)),
            if (c.note != null && c.note!.isNotEmpty)
              _infoRow(Icons.notes_rounded,   'Ghi chú',       c.note!),
          ]),
        ),

        // ── Action buttons ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Row(children: [
            // View PDF
            if (c.fileUrl != null && c.fileUrl!.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent, width: 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: () => _openPdf(c),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Xem hợp đồng', style: TextStyle(fontSize: 12)),
                ),
              ),

            if (c.fileUrl != null && c.isPendingSignature)
              const SizedBox(width: 8),

            // Sign button — only when pending_signature
            if (c.isPendingSignature)
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  onPressed: () => _confirmSign(c),
                  icon: const Icon(Icons.draw_outlined, size: 16),
                  label: const Text('Ký xác nhận', style: TextStyle(fontSize: 12)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _statusBadge(ContractItem c) {
    final (label, color, bg) = switch (c.status) {
      'signed'            => ('Đã ký',          _C.green,  _C.greenLight),
      'pending_signature' => ('Chờ ký',         _C.amber,  _C.amberLight),
      'sent'              => ('Đã gửi',          _C.blue,   _C.blueLight),
      'cancelled'         => ('Đã huỷ',          _C.error,  _C.errorLight),
      'draft'             => ('Bản nháp',        _C.grey,   _C.greyLight),
      _                   => (c.status,          _C.grey,   _C.greyLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: _C.secondary),
      const SizedBox(width: 6),
      SizedBox(
        width: 110,
        child: Text(label, style: const TextStyle(fontSize: 12, color: _C.secondary)),
      ),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.primary)),
      ),
    ]),
  );

  // ─── Helpers ─────────────────────────────────────────────────────────────
  String _ownerLabel(ContractItem c) {
    return switch (c.ownerType.toLowerCase()) {
      'loan_application' => 'Khoản vay #${c.ownerId}',
      'saving'           => 'Sổ tiết kiệm #${c.ownerId}',
      _                  => '${c.ownerType} #${c.ownerId}',
    };
  }

  String _fmtDate(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return value;
    }
  }
}