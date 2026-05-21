import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/loan_api.dart';
import '../api/saving_api.dart';
import '../auth/auth_storage.dart';
import '../security/device_identity.dart';
import '../widgets/loan_list_widget.dart';
import '../widgets/saving_list_widget.dart';
import 'create_loan_screen.dart';
import 'create_saving_screen.dart';
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
  late TabController _tabController;

  List<Loan> _loans = [];
  List<Saving> _savings = [];

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
      _loadSavings(),
    ]);
  }

  Future<void> _loadLoans() async {
    setState(() {
      _loadingLoans = true;
      _loansError = null;
    });
    try {
      final loans = await _loanApi.getLoans();
      if (mounted) {
        setState(() => _loans = loans);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loansError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLoans = false);
      }
    }
  }

  Future<void> _loadSavings() async {
    setState(() {
      _loadingSavings = true;
      _savingsError = null;
    });
    try {
      final savings = await _savingApi.getSavings();
      if (mounted) {
        setState(() => _savings = savings);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingsError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSavings = false);
      }
    }
  }

  int _activeSavingsCount() =>
      _savings.where((s) => s.status.toLowerCase() == 'active').length;

  int _activeLoansCount() =>
      _loans.where((l) => l.status.toLowerCase() == 'active').length;

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
    if (created == true) {
      _loadSavings();
    }
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
    if (created == true) {
      _loadLoans();
    }
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
          'Quan ly Tai san',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _C.blue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              'So tiet kiem va khoan vay cua ban',
              style: TextStyle(fontSize: 13, color: _C.textSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _summaryCard(
                  title: 'Tiet kiem',
                  subtitle: 'so dang co',
                  value: '${_activeSavingsCount()}',
                  borderColor: _C.green,
                  valueColor: _C.green,
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: 'Khoan vay',
                  subtitle: 'dang tra no',
                  value: '${_activeLoansCount()}',
                  borderColor: _C.orange,
                  valueColor: _C.orange,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openCreateSaving,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Mo so moi'),
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
                    label: const Text('Dang ky vay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.blue,
                      side: BorderSide(color: _C.blue.withValues(alpha: 0.35)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                        Tab(text: 'So tiet kiem (${_savings.length})'),
                        Tab(text: 'Khoan vay (${_loans.length})'),
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
                            savings: _savings,
                            loading: _loadingSavings,
                            error: _savingsError,
                            onRefresh: _loadSavings,
                            onTap: _openSavingDetail,
                          );
                        }
                        return LoanListWidget(
                          loans: _loans,
                          loading: _loadingLoans,
                          error: _loansError,
                          onRefresh: _loadLoans,
                          onTap: _openLoanDetail,
                        );
                      },
                    ),
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
