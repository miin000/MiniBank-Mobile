import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/authed_api.dart';
import '../api/loan_api.dart';
import '../api/saving_api.dart';
import '../api/service_request_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import '../widgets/loan_list_widget.dart';
import '../widgets/saving_list_widget.dart';
import 'create_loan_screen.dart';
import 'create_saving_screen.dart';
import 'create_service_request_screen.dart';
import 'expense_management_screen.dart';
import 'limit_change_request_screen.dart';
import 'profile_change_request_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
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
  static const blueGrad = [Color(0xFF2563EB), Color(0xFF4F46E5)];
  static const purpleGrad = [Color(0xFF9333EA), Color(0xFFEC4899)];
  static const greenGrad = [Color(0xFF00C48C), Color(0xFF00A878)];
  static const orangeGrad = [Color(0xFFFF6B35), Color(0xFFFF8C42)];
}
// ──────────────────────────────────────────────────────────────────────────────

class ServicesScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const ServicesScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with SingleTickerProviderStateMixin {
  late LoanApi _loanApi;
  late SavingApi _savingApi;
  late ServiceRequestApi _serviceRequestApi;
  late ScrollController _scrollController;
  late TabController _assetTabController;

  final GlobalKey _assetSectionKey = GlobalKey();
  final GlobalKey _requestSectionKey = GlobalKey();

  List<Loan> _loans = [];
  List<Saving> _savings = [];
  List<ServiceRequest> _serviceRequests = [];

  bool _loadingLoans = false;
  bool _loadingSavings = false;
  bool _loadingServiceRequests = false;

  String? _loansError;
  String? _savingsError;
  String? _serviceRequestsError;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _assetTabController = TabController(length: 2, vsync: this);

    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
    _savingApi = SavingApi(api: api);
    _serviceRequestApi = ServiceRequestApi(api: api);
    _loadAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _assetTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadLoans();
    _loadSavings();
    _loadServiceRequests();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: 0.05);
  }

  Future<void> _loadLoans() async {
    setState(() { _loadingLoans = true; _loansError = null; });
    try {
      final loans = await _loanApi.getLoans();
      if (mounted) setState(() => _loans = loans);
    } catch (e) {
      if (mounted) setState(() => _loansError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingLoans = false);
    }
  }

  Future<void> _loadSavings() async {
    setState(() { _loadingSavings = true; _savingsError = null; });
    try {
      final savings = await _savingApi.getSavings();
      if (mounted) setState(() => _savings = savings);
    } catch (e) {
      if (mounted) setState(() => _savingsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSavings = false);
    }
  }

  Future<void> _loadServiceRequests() async {
    setState(() { _loadingServiceRequests = true; _serviceRequestsError = null; });
    try {
      final requests = await _serviceRequestApi.getServiceRequests();
      if (mounted) setState(() => _serviceRequests = requests);
    } catch (e) {
      if (mounted) setState(() => _serviceRequestsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingServiceRequests = false);
    }
  }


  // ─── Formatters ────────────────────────────────────────────────────────────
  String _fmtCurrency(String amount) {
    try {
      final n = double.parse(amount);
      final s = n.toStringAsFixed(0);
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
        buf.write(s[i]);
      }
      return buf.toString();
    } catch (_) {
      return amount;
    }
  }

  String _fmtDate(String? d) {
    if (d == null) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('active') || l.contains('open')) return _C.green;
    if (l.contains('pending')) return _C.orange;
    if (l.contains('submitted') || l.contains('processing')) return _C.blue;
    if (l.contains('closed') || l.contains('completed')) return _C.textSecondary;
    return _C.textSecondary;
  }

  String _statusLabel(String s) {
    final map = {
      'active': 'Hoạt động', 'open': 'Đang mở', 'pending': 'Chờ duyệt',
      'submitted': 'Đã gửi', 'processing': 'Đang xử lý',
      'closed': 'Đã đóng', 'completed': 'Hoàn tất', 'rejected': 'Từ chối',
    };
    return map[s.toLowerCase()] ?? s;
  }

  // ─── Reusable widgets ──────────────────────────────────────────────────────

  Widget _sectionHeader(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary,
                  letterSpacing: -0.3)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action,
                  style: const TextStyle(
                      fontSize: 13,
                      color: _C.blue,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  void _openExpenseScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseManagementScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
        ),
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String sub,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(height: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: _C.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -0.5)),
        Text(sub,
            style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
      ]),
    );
  }

  Widget _gradientCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ]),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
          ),
        ]),
      ),
    );
  }

  Widget _quickAction({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: gradient.last.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.textPrimary)),
      ]),
    );
  }

  Widget _serviceRequestItem(ServiceRequest req) {
    final color = _statusColor(req.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(req.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel(req.status),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(req.requestType,
            style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
        if (req.description != null && req.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(req.description!,
              style: const TextStyle(fontSize: 12, color: _C.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.access_time, size: 12, color: _C.textSecondary),
          const SizedBox(width: 4),
          Text(_fmtDate(req.submittedAt),
              style: const TextStyle(fontSize: 11, color: _C.textSecondary)),
        ]),
        if (req.processNote != null && req.processNote!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _C.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 14, color: _C.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(req.processNote!,
                    style: const TextStyle(fontSize: 12, color: _C.blue)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }


  Widget _errorState(String msg, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_outlined, size: 40, color: _C.textSecondary),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ]),
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: _C.textSecondary),
          const SizedBox(height: 8),
          Text(msg,
              style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
        ]),
      ),
    );
  }

  // ─── Service requests ──────────────────────────────────────────────────────
  Widget _buildServiceRequestsSection() {
    if (_loadingServiceRequests) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_serviceRequestsError != null) {
      return _errorState(_serviceRequestsError!, _loadServiceRequests);
    }
    if (_serviceRequests.isEmpty) {
      return _emptyState('Chưa có yêu cầu dịch vụ nào', Icons.inbox_outlined);
    }
    return Column(children: _serviceRequests.map(_serviceRequestItem).toList());
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Dịch vụ',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
                letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Stack(children: [
              const Icon(Icons.notifications_outlined, color: _C.textPrimary),
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: _C.orange, shape: BoxShape.circle),
                ),
              ),
            ]),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _C.blue,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // ── Finance summary ────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: _statCard(
                  label: 'Tiết kiệm',
                  value: '${_savings.length}',
                  sub: 'sổ đang hoạt động',
                  accent: _C.green,
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  label: 'Khoản vay',
                  value: '${_loans.length}',
                  sub: 'đang trả nợ',
                  accent: _C.orange,
                  icon: Icons.credit_score_outlined,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Feature cards ──────────────────────────────────────────────
            _gradientCard(
              title: 'Quản lý Tài sản',
              subtitle: 'Sổ tiết kiệm, khoản vay và chi tiết',
              icon: Icons.account_balance_wallet_outlined,
              colors: _C.blueGrad,
              onTap: () => _scrollTo(_assetSectionKey),
            ),
            const SizedBox(height: 10),
            _gradientCard(
              title: 'Quản lý chi tiêu thông minh',
              subtitle: 'Theo dõi thu chi, phân loại giao dịch',
              icon: Icons.query_stats_outlined,
              colors: _C.purpleGrad,
              onTap: _openExpenseScreen,
            ),
            const SizedBox(height: 20),

            // ── Quick actions ──────────────────────────────────────────────
            _sectionHeader('Thao tác nhanh'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(
                  label: 'Mở sổ\ntiết kiệm',
                  icon: Icons.add_circle_outline,
                  gradient: _C.greenGrad,
                  onTap: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => CreateSavingScreen(
                        baseUrl: widget.baseUrl,
                        storage: widget.storage,
                        identity: widget.identity,
                      )),
                    );
                    if (res == true) _loadSavings();
                  },
                ),
                _quickAction(
                  label: 'Đăng ký\nvay vốn',
                  icon: Icons.credit_card_outlined,
                  gradient: _C.blueGrad,
                  onTap: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => CreateLoanScreen(
                        baseUrl: widget.baseUrl,
                        storage: widget.storage,
                        identity: widget.identity,
                      )),
                    );
                    if (res == true) _loadLoans();
                  },
                ),
                _quickAction(
                  label: 'Yêu cầu\ndịch vụ',
                  icon: Icons.assignment_outlined,
                  gradient: _C.purpleGrad,
                  onTap: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => CreateServiceRequestScreen(
                        baseUrl: widget.baseUrl,
                        storage: widget.storage,
                        identity: widget.identity,
                      )),
                    );
                    if (res == true) _loadServiceRequests();
                  },
                ),
                _quickAction(
                  label: 'Thống kê\nchi tiêu',
                  icon: Icons.pie_chart_outline,
                  gradient: _C.orangeGrad,
                  onTap: _openExpenseScreen,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Asset section (Savings + Loans tabbed) ─────────────────────
            Container(
              key: _assetSectionKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeader('Tài sản của tôi',
                    action: 'Xem chi tiêu',
                  onAction: _openExpenseScreen),
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                      color: _C.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: TabBar(
                    controller: _assetTabController,
                    indicator: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8, offset: const Offset(0, 2))
                        ]),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: _C.textPrimary,
                    unselectedLabelColor: _C.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Tiết kiệm  (${_savings.length})'),
                      Tab(text: 'Khoản vay  (${_loans.length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: ListenableBuilder(
                    listenable: _assetTabController,
                    builder: (_, __) {
                      if (_assetTabController.index == 0) {
                        return SavingListWidget(
                          savings: _savings,
                          loading: _loadingSavings,
                          error: _savingsError,
                          onRefresh: _loadSavings,
                        );
                      }
                      return LoanListWidget(
                        loans: _loans,
                        loading: _loadingLoans,
                        error: _loansError,
                        onRefresh: _loadLoans,
                      );
                    },
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Service requests section ───────────────────────────────────
            Container(
              key: _requestSectionKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionHeader('Yêu cầu dịch vụ'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _quickAction(
                      label: 'Nâng\n hạn mức',
                      icon: Icons.trending_up,
                      gradient: _C.greenGrad,
                      onTap: () async {
                        final res = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => LimitChangeRequestScreen(
                              baseUrl: widget.baseUrl,
                              storage: widget.storage,
                              identity: widget.identity,
                            ),
                          ),
                        );
                        if (res == true) _loadServiceRequests();
                      },
                    ),
                    _quickAction(
                      label: 'Đổi\n thông tin',
                      icon: Icons.edit_note,
                      gradient: _C.blueGrad,
                      onTap: () async {
                        final res = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ProfileChangeRequestScreen(
                              baseUrl: widget.baseUrl,
                              storage: widget.storage,
                              identity: widget.identity,
                            ),
                          ),
                        );
                        if (res == true) _loadServiceRequests();
                      },
                    ),
                    _quickAction(
                      label: 'Yêu cầu\n khác',
                      icon: Icons.assignment_outlined,
                      gradient: _C.purpleGrad,
                      onTap: () async {
                        final res = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => CreateServiceRequestScreen(
                            baseUrl: widget.baseUrl,
                            storage: widget.storage,
                            identity: widget.identity,
                          )),
                        );
                        if (res == true) _loadServiceRequests();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildServiceRequestsSection(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}