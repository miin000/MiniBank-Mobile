import 'package:flutter/material.dart';

import '../api/authed_api.dart';
import '../api/expense_api.dart';
import '../api/transaction_api.dart';
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
}

class ExpenseManagementScreen extends StatefulWidget {
  final String baseUrl;
  final AuthStorage storage;

  const ExpenseManagementScreen({
    super.key,
    required this.baseUrl,
    required this.storage,
  });

  @override
  State<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  late ExpenseApi _expenseApi;
  late TransactionApi _transactionApi;

  bool _loadingExpense = false;
  bool _loadingRecommendations = false;
  bool _loadingTransactions = false;
  int? _classifyingTransactionId;
  String? _expenseError;
  String? _recommendationError;
  String? _transactionsError;

  ExpenseOverview? _expenseOverview;
  List<ExpenseCategoryOption> _expenseCategories = const [];
  DailyRecommendation? _dailyRecommendation;
  List<TransactionSummary> _recentTransactions = const [];

  @override
  void initState() {
    super.initState();
    final api = AuthedApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _expenseApi = ExpenseApi(api: api);
    _transactionApi = TransactionApi(baseUrl: widget.baseUrl, storage: widget.storage);
    _loadAll();
  }

  Future<void> _loadAll() async {
    _loadExpense();
    _loadRecommendations();
    _loadRecentTransactions();
  }

  Future<void> _loadExpense() async {
    setState(() {
      _loadingExpense = true;
      _expenseError = null;
    });
    try {
      final overview = await _expenseApi.getOverview(flowType: 'out');
      final categories = await _expenseApi.getCategories(flowType: 'out');
      if (mounted) {
        setState(() {
          _expenseOverview = overview;
          _expenseCategories = categories;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _expenseError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingExpense = false);
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecommendations = true;
      _recommendationError = null;
    });
    try {
      final recommendation = await _expenseApi.getDailyRecommendation();
      if (mounted) setState(() => _dailyRecommendation = recommendation);
    } catch (e) {
      if (mounted) setState(() => _recommendationError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRecommendations = false);
    }
  }

  Future<void> _loadRecentTransactions() async {
    setState(() {
      _loadingTransactions = true;
      _transactionsError = null;
    });
    try {
      final items = await _transactionApi.recent(limit: 20);
      final filtered = items
          .where((tx) => tx.direction == 'out' && tx.status == 'completed')
          .toList(growable: false);
      if (mounted) setState(() => _recentTransactions = filtered);
    } catch (e) {
      if (mounted) setState(() => _transactionsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  Future<void> _classifyTransaction(int txId, String code) async {
    setState(() => _classifyingTransactionId = txId);
    try {
      await _expenseApi.classifyTransaction(
        transactionId: txId,
        categoryCode: code,
        flowType: 'out',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Da phan loai giao dich')));
      await _loadExpense();
      await _loadRecentTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('That bai: $e')));
    } finally {
      if (mounted) setState(() => _classifyingTransactionId = null);
    }
  }

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

  String _categoryName(String? code) {
    if (code == null || code.isEmpty) return 'Chua phan loai';
    for (final option in _expenseCategories) {
      if (option.categoryCode == code) return option.categoryName;
    }
    return code;
  }

  Future<void> _showCategoryPicker(TransactionSummary tx) async {
    if (_expenseCategories.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: _expenseCategories
              .map(
                (cat) => ListTile(
                  title: Text(cat.categoryName),
                  onTap: () {
                    Navigator.of(context).pop();
                    _classifyTransaction(tx.id, cat.categoryCode);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _miniStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _C.textSecondary)),
      ]),
    );
  }

  Widget _categoryRow(ExpenseCategorySummary item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              item.categoryName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${item.transactionCount} giao dich',
              style: const TextStyle(fontSize: 11, color: _C.textSecondary),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${_fmtCurrency(item.amount)} d',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          Text(
            '${item.percentage}%',
            style: const TextStyle(
              fontSize: 11,
              color: _C.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _unclassifiedCard(UnclassifiedExpenseTransaction tx) {
    final processing = _classifyingTransactionId == tx.transactionId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(
              tx.description?.isNotEmpty == true
                  ? tx.description!
                  : tx.transactionType,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_fmtCurrency(tx.amount)} d',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.orange,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (processing)
          const LinearProgressIndicator(minHeight: 2)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _expenseCategories
                .map(
                  (cat) => GestureDetector(
                    onTap: () => _classifyTransaction(tx.transactionId, cat.categoryCode),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.blue.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.blue.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        cat.categoryName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _C.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ]),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return _C.orange;
      case 'MEDIUM':
        return _C.blue;
      default:
        return _C.green;
    }
  }

  Widget _recommendationCard(RecommendationItem item) {
    final color = _priorityColor(item.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.message,
          style: const TextStyle(fontSize: 12, color: _C.textSecondary),
        ),
      ]),
    );
  }

  Widget _buildRecommendationSection() {
    if (_loadingRecommendations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_recommendationError != null) {
      return _errorState(_recommendationError!, _loadRecommendations);
    }
    final recommendation = _dailyRecommendation;
    if (recommendation == null || recommendation.recommendations.isEmpty) {
      return _emptyState('Chua co goi y hom nay', Icons.tips_and_updates_outlined);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Goi y hom nay',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _C.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      ...recommendation.recommendations.map(_recommendationCard),
    ]);
  }

  Widget _buildRecentTransactionsSection() {
    if (_loadingTransactions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_transactionsError != null) {
      return _errorState(_transactionsError!, _loadRecentTransactions);
    }
    if (_recentTransactions.isEmpty) {
      return _emptyState('Chua co giao dich nao', Icons.receipt_long_outlined);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Giao dich gan day',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _C.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      ..._recentTransactions.map((tx) {
        final categoryLabel = _categoryName(tx.categoryCode);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  tx.description?.isNotEmpty == true
                      ? tx.description!
                      : tx.transactionType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtCurrency(tx.amount)} d',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _C.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
            GestureDetector(
              onTap: () => _showCategoryPicker(tx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.blue.withValues(alpha: 0.15)),
                ),
                child: Text(
                  categoryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _errorState(String msg, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_outlined, size: 40, color: _C.textSecondary),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _C.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: const Text('Thu lai')),
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
          Text(msg, style: const TextStyle(fontSize: 13, color: _C.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildExpenseSection() {
    if (_loadingExpense) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_expenseError != null) {
      return _errorState(_expenseError!, _loadExpense);
    }
    final ov = _expenseOverview;
    if (ov == null) {
      return _emptyState('Chua co du lieu chi tieu', Icons.pie_chart_outline);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: _miniStatCard(
            label: 'Tong chi',
            value: '${_fmtCurrency(ov.selectedFlowTotal)} d',
            icon: Icons.trending_down,
            color: _C.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            label: 'Giao dich',
            value: '${ov.selectedFlowTransactionCount}',
            icon: Icons.receipt_outlined,
            color: _C.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStatCard(
            label: 'Chua phan loai',
            value: '${ov.unclassifiedTransactionCount}',
            icon: Icons.label_outline,
            color: _C.purple,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _buildRecommendationSection(),
      if (ov.categories.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'Phan bo danh muc',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...ov.categories.map((item) => _categoryRow(item)),
      ],
      if (ov.unclassifiedTransactions.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'Can phan loai',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...ov.unclassifiedTransactions.map((tx) => _unclassifiedCard(tx)),
      ],
      const SizedBox(height: 16),
      _buildRecentTransactionsSection(),
    ]);
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
          'Quan ly chi tieu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _C.blue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _buildExpenseSection(),
          ],
        ),
      ),
    );
  }
}
