import 'dart:math' as math;

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
  static const red = Color(0xFFEF4444);
}

// ──────────────────────────────────────────────
// Enums for tab state
// ──────────────────────────────────────────────
enum _FlowTab { expense, income }
enum _ChartTab { distribution, trend }

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

  _FlowTab _flowTab = _FlowTab.expense;
  _ChartTab _chartTab = _ChartTab.distribution;

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
      final flowType = _flowTab == _FlowTab.expense ? 'out' : 'in';
      final overview = await _expenseApi.getOverview(flowType: flowType);
      final categories = await _expenseApi.getCategories(flowType: flowType);
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
      final direction = _flowTab == _FlowTab.expense ? 'out' : 'in';
      final filtered = items
          .where((tx) => tx.direction == direction && tx.status == 'completed')
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
          .showSnackBar(const SnackBar(content: Text('Đã phân loại giao dịch')));
      await _loadExpense();
      await _loadRecentTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Thất bại: $e')));
    } finally {
      if (mounted) setState(() => _classifyingTransactionId = null);
    }
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

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

  double _asDouble(String value) => double.tryParse(value) ?? 0;

  String _categoryName(String? code) {
    if (code == null || code.isEmpty) return 'Chưa phân loại';
    for (final option in _expenseCategories) {
      if (option.categoryCode == code) return option.categoryName;
    }
    return code;
  }

  Color _categoryColor(int index) {
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  Color _recommendationColor(String priority) {
    return switch (priority.toUpperCase()) {
      'HIGH' => const Color(0xFFDC2626),
      'MEDIUM' => const Color(0xFFD97706),
      _ => _C.blue,
    };
  }

  String _recommendationSourceLabel(String source) {
    return source == 'RULE_BASED_AND_GEMINI' ? 'Gemini AI' : 'Quy tắc thông minh';
  }

  Future<void> _showCategoryPicker(TransactionSummary tx) async {
    if (_expenseCategories.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Chọn danh mục',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _C.textPrimary),
              ),
            ),
            Flexible(
              child: ListView(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Widgets
  // ──────────────────────────────────────────────

  Widget _topMetrics(ExpenseOverview ov) {
    return Row(children: [
      _topMetricCard(
        label: 'Tổng thu',
        amount: ov.totalIncome,
        icon: Icons.trending_up_rounded,
        color: _C.green,
      ),
      const SizedBox(width: 14),
      _topMetricCard(
        label: 'Tổng chi',
        amount: ov.totalExpense,
        icon: Icons.trending_down_rounded,
        color: _C.red,
      ),
    ]);
  }

  Widget _topMetricCard({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: _C.textSecondary, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 14),
          Text(
            _fmtCurrency(amount),
            style: TextStyle(
                fontSize: 22,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 3),
          const Text('VND',
              style: TextStyle(fontSize: 12, color: _C.textSecondary)),
        ]),
      ),
    );
  }

  Widget _flowAndChartTabs() {
    return Column(children: [
      // Row 1: Phân loại chi / Phân loại thu
      Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _tabButton(
            label: 'Phân loại chi',
            selected: _flowTab == _FlowTab.expense,
            selectedColor: _C.red,
            onTap: () {
              if (_flowTab != _FlowTab.expense) {
                setState(() => _flowTab = _FlowTab.expense);
                _loadExpense();
                _loadRecentTransactions();
              }
            },
          ),
          _tabButton(
            label: 'Phân loại thu',
            selected: _flowTab == _FlowTab.income,
            selectedColor: _C.green,
            onTap: () {
              if (_flowTab != _FlowTab.income) {
                setState(() => _flowTab = _FlowTab.income);
                _loadExpense();
                _loadRecentTransactions();
              }
            },
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // Row 2: Phân bổ / Xu hướng
      Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          _tabButton(
            label: 'Phân bổ',
            icon: Icons.pie_chart_outline_rounded,
            selected: _chartTab == _ChartTab.distribution,
            selectedColor: _C.blue,
            onTap: () => setState(() => _chartTab = _ChartTab.distribution),
          ),
          _tabButton(
            label: 'Xu hướng',
            icon: Icons.bar_chart_rounded,
            selected: _chartTab == _ChartTab.trend,
            selectedColor: _C.blue,
            onTap: () => setState(() => _chartTab = _ChartTab.trend),
          ),
        ]),
      ),
    ]);
  }

  Widget _tabButton({
    required String label,
    IconData? icon,
    required bool selected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17,
                    color: selected ? Colors.white : _C.textSecondary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _C.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pie chart card ──────────────────────────────
  Widget _distributionCard(ExpenseOverview ov) {
    final categories = ov.categories;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        SizedBox(
          height: 240,
          child: categories.isEmpty
              ? _emptyState('Chưa có phân bổ danh mục', Icons.pie_chart_outline)
              : CustomPaint(
                  painter: _PieChartPainter(
                      categories, _asDouble(ov.selectedFlowTotal), _categoryColor),
                  child: Center(
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmtCurrency(ov.selectedFlowTotal),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: _C.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3),
                            ),
                            const Text('VND',
                                style: TextStyle(
                                    fontSize: 11, color: _C.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F1F5)),
        const SizedBox(height: 4),
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _flowTab == _FlowTab.expense ? 'Danh mục chi tiêu' : 'Danh mục thu nhập',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary),
            ),
          ),
        ),
        ...categories.asMap().entries
            .map((e) => _categoryRow(e.value, _categoryColor(e.key))),
      ]),
    );
  }

  Widget _categoryRow(ExpenseCategorySummary item, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F1F5)))),
      child: Row(children: [
        Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(
            child: Text(item.categoryName,
                style: const TextStyle(fontSize: 15, color: _C.textPrimary))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmtCurrency(item.amount)} VND',
              style: const TextStyle(
                  fontSize: 14,
                  color: _C.textPrimary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${item.percentage}%',
              style: const TextStyle(fontSize: 12, color: _C.textSecondary)),
        ]),
      ]),
    );
  }

  // ── Bar chart (trend) ───────────────────────────
  Widget _trendCard(ExpenseOverview ov) {
    final months = ov.monthlyTrend;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (months.isEmpty)
          SizedBox(
            height: 220,
            child: _emptyState('Chưa có dữ liệu xu hướng', Icons.bar_chart),
          )
        else
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _BarChartPainter(months, _C.blue),
              size: const Size(double.infinity, 220),
            ),
          ),
        const Divider(height: 1, color: Color(0xFFF0F1F5)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _flowTab == _FlowTab.expense ? 'Danh mục chi tiêu' : 'Danh mục thu nhập',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        ...ov.categories.asMap().entries
            .map((e) => _categoryRow(e.value, _categoryColor(e.key))),
      ]),
    );
  }

  // ── Unclassified panel ──────────────────────────
  Widget _unclassifiedPanel(ExpenseOverview ov) {
    final items = ov.unclassifiedTransactions;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC8A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              'Chưa phân loại (${items.length})',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _C.textPrimary),
            ),
          ),
          TextButton(
            onPressed: items.isEmpty || _expenseCategories.isEmpty
                ? null
                : () => _classifyTransaction(
                    items.first.transactionId,
                    _expenseCategories.first.categoryCode),
            style: TextButton.styleFrom(
              foregroundColor: _C.orange,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Phân loại ngay'),
          ),
        ]),
        const SizedBox(height: 8),
        ...items.take(4).map((tx) {
          final processing = _classifyingTransactionId == tx.transactionId;
          return InkWell(
            onTap: processing ? null : () => _showUnclassifiedPicker(tx),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(
                    tx.description?.isNotEmpty == true
                        ? tx.description!
                        : tx.transactionType,
                    style: const TextStyle(fontSize: 14, color: _C.textPrimary),
                  ),
                ),
                processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _fmtCurrency(tx.amount),
                        style: const TextStyle(
                            fontSize: 14,
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w500),
                      ),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Future<void> _showUnclassifiedPicker(UnclassifiedExpenseTransaction tx) async {
    if (_expenseCategories.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Chọn danh mục',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _expenseCategories
                    .map((cat) => ListTile(
                          title: Text(cat.categoryName),
                          onTap: () {
                            Navigator.of(context).pop();
                            _classifyTransaction(tx.transactionId, cat.categoryCode);
                          },
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent transactions ─────────────────────────
  Widget _recentTransactionsPanel() {
    if (_loadingTransactions) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator()));
    }
    if (_transactionsError != null) {
      return _errorState(_transactionsError!, _loadRecentTransactions);
    }
    if (_recentTransactions.isEmpty) {
      return _emptyState('Chưa có giao dịch nào', Icons.receipt_long_outlined);
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Giao dịch gần đây',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary)),
        const SizedBox(height: 8),
        ..._recentTransactions.take(6).map((tx) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tx.description?.isNotEmpty == true
                  ? tx.description!
                  : tx.transactionType),
              subtitle: Text(_categoryName(tx.categoryCode),
                  style: const TextStyle(color: _C.textSecondary)),
              trailing: Text(
                '${_fmtCurrency(tx.amount)} VND',
                style: const TextStyle(
                    color: _C.red, fontWeight: FontWeight.w700),
              ),
              onTap: () => _showCategoryPicker(tx),
            )),
      ]),
    );
  }

  // ── AI Recommendation panel ─────────────────────
  Widget _recommendationPanel() {
    final rec = _dailyRecommendation;
    if (_loadingRecommendations) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Đang tải đề xuất chi tiêu...',
              style: TextStyle(color: _C.textSecondary)),
        ]),
      );
    }
    if (_recommendationError != null) {
      return Container(
        decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(16)),
        child: _errorState(_recommendationError!, _loadRecommendations),
      );
    }
    if (rec == null || rec.recommendations.isEmpty) {
      return Container(
        decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(16)),
        child: _emptyState(
            'Chưa có đề xuất chi tiêu', Icons.auto_awesome_outlined),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.purple.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: _C.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child:
                const Icon(Icons.auto_awesome_rounded, color: _C.purple, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Đề xuất chi tiêu',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    '${_recommendationSourceLabel(rec.source)} • ${rec.month} • Điểm tiết kiệm ${rec.savingScore}/100',
                    style: const TextStyle(
                        fontSize: 11, color: _C.textSecondary)),
              ])),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: _recommendationColor(rec.riskLevel)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999)),
            child: Text(rec.riskLevel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _recommendationColor(rec.riskLevel))),
          ),
        ]),
        const SizedBox(height: 14),
        ...rec.recommendations.map((item) {
          final color = _recommendationColor(item.priority);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.14)),
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: color, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color)),
                        const SizedBox(height: 4),
                        Text(item.message,
                            style: const TextStyle(
                                fontSize: 13,
                                color: _C.textPrimary,
                                height: 1.4)),
                      ])),
                ]),
          );
        }),
      ]),
    );
  }

  // ── Utilities ───────────────────────────────────
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

  // ── Main section builder ────────────────────────
  Widget _buildExpenseSection() {
    if (_loadingExpense) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator()));
    }
    if (_expenseError != null) {
      return _errorState(_expenseError!, _loadExpense);
    }
    final ov = _expenseOverview;
    if (ov == null) {
      return _emptyState('Chưa có dữ liệu chi tiêu', Icons.pie_chart_outline);
    }

    final chartWidget = _chartTab == _ChartTab.distribution
        ? _distributionCard(ov)
        : _trendCard(ov);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _topMetrics(ov),
      const SizedBox(height: 20),
      _recommendationPanel(),
      const SizedBox(height: 20),
      _flowAndChartTabs(),
      const SizedBox(height: 16),
      chartWidget,
      _unclassifiedPanel(ov),
      _recentTransactionsPanel(),
    ]);
  }

  // ── Build ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left, color: _C.blue),
          label: const Text('Quay lại',
              style: TextStyle(color: _C.blue, fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 6),
              minimumSize: const Size(100, 40)),
        ),
        leadingWidth: 120,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _C.blue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
          children: [
            const Text('Quản lý chi tiêu',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                    letterSpacing: -0.5)),
            const SizedBox(height: 24),
            _buildExpenseSection(),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Pie chart painter
// ──────────────────────────────────────────────
class _PieChartPainter extends CustomPainter {
  final List<ExpenseCategorySummary> categories;
  final double total;
  final Color Function(int index) colorFor;

  _PieChartPainter(this.categories, this.total, this.colorFor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.30;
    final outerRadius = size.shortestSide * 0.46;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);
    var start = -90.0;
    final paint = Paint()..style = PaintingStyle.fill;
    final effectiveTotal = total > 0
        ? total
        : categories.fold<double>(
            0, (sum, e) => sum + (double.tryParse(e.amount) ?? 0));

    for (var i = 0; i < categories.length; i++) {
      final item = categories[i];
      final value = double.tryParse(item.amount) ?? 0;
      final sweep =
          effectiveTotal <= 0 ? 0.0 : value / effectiveTotal * 360;
      paint.color = colorFor(i);
      canvas.drawArc(rect, _deg(start), _deg(sweep), true, paint);

      if (sweep > 15) {
        final mid = _deg(start + sweep / 2);
        final labelRadius = outerRadius + 40;
        final labelOffset = Offset(
          center.dx + labelRadius * math.cos(mid),
          center.dy + labelRadius * math.sin(mid),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${item.categoryName} ${item.percentage}%',
            style: TextStyle(
                color: colorFor(i),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 110);
        tp.paint(canvas, labelOffset - Offset(tp.width / 2, tp.height / 2));
      }
      start += sweep;
    }

    // Donut hole
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
  }

  double _deg(double value) => value * math.pi / 180;

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.categories != categories || oldDelegate.total != total;
}

// ──────────────────────────────────────────────
// Bar chart painter (trend view)
// ──────────────────────────────────────────────
class _BarChartPainter extends CustomPainter {
  final List<MonthlyTrendItem> items;
  final Color barColor;

  _BarChartPainter(this.items, this.barColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final maxValue = items.fold<double>(
        0, (m, e) => math.max(m, double.tryParse(e.amount) ?? 0));
    if (maxValue <= 0) return;

    const paddingLeft = 56.0;
    const paddingBottom = 32.0;
    const paddingTop = 16.0;
    const paddingRight = 12.0;
    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingBottom - paddingTop;

    final axisPaint = Paint()
      ..color = const Color(0xFFE8EAF0)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = paddingTop + chartHeight - (chartHeight * i / 4);
      canvas.drawLine(
          Offset(paddingLeft, y), Offset(size.width - paddingRight, y), axisPaint);

      final labelValue = (maxValue * i / 4).round();
      final tp = TextPainter(
        text: TextSpan(
          text: _shortLabel(labelValue.toDouble()),
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7299)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    final barWidth = (chartWidth / items.length) * 0.55;
    final gap = chartWidth / items.length;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < items.length; i++) {
      final value = double.tryParse(items[i].amount) ?? 0;
      final barH = (value / maxValue) * chartHeight;
      final x = paddingLeft + gap * i + (gap - barWidth) / 2;
      final y = paddingTop + chartHeight - barH;

      final rRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, barH),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rRect, barPaint);

      // X label
      final tp = TextPainter(
        text: TextSpan(
          text: items[i].label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7299)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(x + barWidth / 2 - tp.width / 2,
              paddingTop + chartHeight + 6));
    }
  }

  String _shortLabel(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.items != items || old.barColor != barColor;
}