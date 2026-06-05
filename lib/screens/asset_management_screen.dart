import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/contract_api.dart';
import '../api/loan_api.dart';
import '../api/saving_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import '../widgets/loan_list_widget.dart';
import '../widgets/saving_list_widget.dart';
import 'create_loan_screen.dart';
import 'create_saving_screen.dart';
import 'loan_contracts_screen.dart';
import 'loan_detail_screen.dart';
import 'saving_detail_screen.dart';

class _C {
  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8EAF0);
  static const textPrimary = Color(0xFF0D1B3E);
  static const textSecondary = Color(0xFF6B7299);
  static const green = Color(0xFF00A86B);
  static const orange = Color(0xFFF97316);
  static const blue = Color(0xFF2563EB);
}

class AssetManagementScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;
  final DeviceIdentity identity;

  const AssetManagementScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
    required this.identity,
  });

  @override
  State<AssetManagementScreen> createState() => _AssetManagementScreenState();
}

class _AssetManagementScreenState extends State<AssetManagementScreen>
    with SingleTickerProviderStateMixin {
  late LoanApi _loanApi;
  late SavingApi _savingApi;
  late ContractApi _contractApi;
  late TabController _tabController;

  List<Loan> _loans = [];
  List<Saving> _savings = [];
  List<LoanApplication> _loanApplications = [];

  /// Number of pending (unsigned) loan contracts — shown as badge
  int _pendingContractCount = 0;

  bool _loadingLoans = false;
  bool _loadingSavings = false;
  String? _loansError;
  String? _savingsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loanApi = LoanApi(api: api);
    _savingApi = SavingApi(api: api);
    _contractApi = ContractApi(api: api);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadLoans(),
      _loadLoanApplications(),
      _loadSavings(),
      _loadPendingContracts(),
    ]);
  }

  Future<void> _loadLoans() async {
    setState(() {
      _loadingLoans = true;
      _loansError = null;
    });
    try {
      final loans = await _loanApi.getLoans();
      if (mounted) setState(() => _loans = loans);
    } catch (e) {
      if (mounted) setState(() => _loansError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingLoans = false);
    }
  }

  Future<void> _loadLoanApplications() async {
    try {
      final apps = await _loanApi.getMyApplications();
      if (mounted) setState(() => _loanApplications = apps);
    } catch (_) {
      // Non-critical: the loan list still renders if the application badge fails.
    }
  }

  Future<void> _loadSavings() async {
    setState(() {
      _loadingSavings = true;
      _savingsError = null;
    });
    try {
      final savings = await _savingApi.getSavings();
      if (mounted) setState(() => _savings = savings);
    } catch (e) {
      if (mounted) setState(() => _savingsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSavings = false);
    }
  }

  Future<void> _loadPendingContracts() async {
    try {
      final contracts = await _contractApi.getMobileContracts();
      final count = contracts.where((c) => c.isForLoan && !c.isSigned).length;
      if (mounted) setState(() => _pendingContractCount = count);
    } catch (_) {
      // non-critical — badge just won't show
    }
  }

  int _activeSavingsCount() =>
      _visibleSavings.length;

  int _activeLoansCount() =>
      _visibleLoans.length;

  bool _isVisibleSaving(Saving saving) {
    final status = saving.status.toLowerCase();
    return status == 'active' || status == 'open';
  }

  bool _isVisibleLoan(Loan loan) {
    final status = loan.status.toLowerCase();
    final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
    if (outstanding <= 0) return false;
    return status == 'active' || status == 'open' || status == 'disbursed';
  }

  List<Saving> get _visibleSavings => _savings.where(_isVisibleSaving).toList(growable: false);

  List<Loan> get _visibleLoans => _loans.where(_isVisibleLoan).toList(growable: false);

  int _unsyncedLoanCount() {
    final syncedApplicationIds = _loans.map((l) => l.loanApplicationId).toSet();
    return _loanApplications.where((app) {
      final status = app.status.toLowerCase();
      if (syncedApplicationIds.contains(app.id)) return false;
      return status == 'approved' ||
          status == 'contract_pending' ||
          status == 'pending_signature';
    }).length;
  }

  Future<void> _openCreateSaving() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSavingScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );
    if (created == true) _loadSavings();
  }

  Future<void> _openCreateLoan() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateLoanScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          identity: widget.identity,
        ),
      ),
    );
    if (created == true) _loadLoans();
  }

  Future<void> _openLoanContracts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanContractsScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
        ),
      ),
    );
    // Reload after returning — user may have signed a contract
    _loadAll();
  }

  Future<void> _openSavingDetail(Saving saving) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavingDetailScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          savingId: saving.id,
        ),
      ),
    );
  }

  Future<void> _openLoanDetail(Loan loan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(
          baseUrl: widget.baseUrl,
          storage: widget.storage,
          loanId: loan.id,
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String subtitle,
    required String value,
    required Color borderColor,
    required Color valueColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: valueColor),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _C.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Orange banner shown when user has approved loan applications
  /// with unsigned contracts waiting
  Widget _pendingContractBanner() {
    if (_pendingContractCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _openLoanContracts,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined, size: 18, color: _C.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bạn có $_pendingContractCount hợp đồng vay chờ ký — nhấn để xem và ký nhận giải ngân.',
                style: const TextStyle(fontSize: 13, color: _C.orange),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _C.orange),
          ],
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
          'Quản lý Tài sản',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        actions: [
          // Contracts shortcut with badge
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                onPressed: _openLoanContracts,
                tooltip: 'Đơn vay & Hợp đồng',
                icon: const Icon(Icons.description_outlined, color: _C.blue),
              ),
              if (_pendingContractCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: _C.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_pendingContractCount',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _C.blue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'Sổ tiết kiệm và khoản vay của bạn',
              style: TextStyle(fontSize: 13, color: _C.textSecondary),
            ),
            const SizedBox(height: 14),

            // Pending contract banner
            _pendingContractBanner(),

            // Summary cards
            Row(
              children: [
                _summaryCard(
                  title: 'Tiết kiệm',
                  subtitle: 'sổ đang có',
                  value: '${_activeSavingsCount()}',
                  borderColor: _C.green,
                  valueColor: _C.green,
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Khoản vay',
                  subtitle: _unsyncedLoanCount() > 0
                      ? '${_unsyncedLoanCount()} chưa đồng bộ'
                      : '${_activeLoansCount()} đang hoạt động / ${_loans.length} tổng',
                  value: '${_activeLoansCount()}',
                  borderColor: _C.orange,
                  valueColor: _C.orange,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCreateSaving,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Mở sổ mới'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.green,
                      side: BorderSide(color: _C.green.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCreateLoan,
                    icon: const Icon(Icons.credit_card_outlined),
                    label: const Text('Đăng ký vay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.blue,
                      side: BorderSide(color: _C.blue.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab list
            Container(
              decoration: BoxDecoration(
                color: _C.surface,
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: _C.blue,
                      labelColor: _C.textPrimary,
                      unselectedLabelColor: _C.textSecondary,
                      tabs: [
                        Tab(text: 'Sổ tiết kiệm (${_visibleSavings.length})'),
                        Tab(text: 'Khoản vay (${_visibleLoans.length})'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: ListenableBuilder(
                      listenable: _tabController,
                      builder: (_, __) {
                        if (_tabController.index == 0) {
                          return SavingListWidget(
                            savings: _visibleSavings,
                            loading: _loadingSavings,
                            error: _savingsError,
                            onRefresh: _loadSavings,
                            onTap: _openSavingDetail,
                          );
                        }
                        return LoanListWidget(
                          loans: _visibleLoans,
                          loading: _loadingLoans,
                          error: _loansError,
                          onRefresh: _loadLoans,
                          onTap: _openLoanDetail,
                        );
                      },
                    ),
                  ),

                  // When loans tab is active and empty, show shortcut to contracts
                  ListenableBuilder(
                    listenable: _tabController,
                    builder: (_, __) {
                      if (_tabController.index != 1) {
                        return const SizedBox.shrink();
                      }
                      if (_loadingLoans || _visibleLoans.isNotEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: OutlinedButton.icon(
                          onPressed: _openLoanContracts,
                          icon: const Icon(
                            Icons.description_outlined,
                            size: 16,
                          ),
                          label: const Text('Xem đơn vay & ký hợp đồng'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.blue,
                            side: BorderSide(
                              color: _C.blue.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
