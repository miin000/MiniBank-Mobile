import 'authed_api.dart';

class ExpenseCategorySummary {
  final String categoryCode;
  final String categoryName;
  final String amount;
  final String percentage;
  final int transactionCount;

  ExpenseCategorySummary({
    required this.categoryCode,
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExpenseCategorySummary(
      categoryCode: json['categoryCode']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      percentage: json['percentage']?.toString() ?? '0',
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
    );
  }
}


class MonthlyTrendItem {
  final String month;
  final String amount;

  String get label => month;

  MonthlyTrendItem({required this.month, required this.amount});

  factory MonthlyTrendItem.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendItem(
      month: (json['month'] ?? json['label'] ?? json['period'])?.toString() ?? '',
      amount: (json['amount'] ?? json['total'])?.toString() ?? '0',
    );
  }
}

class RecommendationItem {
  final String type;
  final String title;
  final String message;
  final String priority;

  RecommendationItem({
    required this.type,
    required this.title,
    required this.message,
    required this.priority,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'LOW',
    );
  }
}

class DailyRecommendation {
  final String month;
  final String riskLevel;
  final int savingScore;
  final List<RecommendationItem> recommendations;
  final String source;

  DailyRecommendation({
    required this.month,
    required this.riskLevel,
    required this.savingScore,
    required this.recommendations,
    required this.source,
  });

  factory DailyRecommendation.fromJson(Map<String, dynamic> json) {
    final items = (json['recommendations'] as List<dynamic>? ?? const [])
        .map((e) => RecommendationItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    final savingRaw = json['saving_score'] ?? json['savingScore'];
    return DailyRecommendation(
      month: json['month']?.toString() ?? '',
      riskLevel: (json['risk_level'] ?? json['riskLevel'])?.toString() ?? 'LOW',
      savingScore: (savingRaw as num?)?.toInt() ?? 0,
      recommendations: items,
      source: json['source']?.toString() ?? 'RULE_BASED',
    );
  }
}

class UnclassifiedExpenseTransaction {
  final int transactionId;
  final String transactionCode;
  final String direction;
  final String amount;
  final String? description;
  final String? counterpartyAccountNumber;
  final String? counterpartyAccountName;
  final String transactionType;
  final String? createdAt;

  UnclassifiedExpenseTransaction({
    required this.transactionId,
    required this.transactionCode,
    required this.direction,
    required this.amount,
    this.description,
    this.counterpartyAccountNumber,
    this.counterpartyAccountName,
    required this.transactionType,
    this.createdAt,
  });

  factory UnclassifiedExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return UnclassifiedExpenseTransaction(
      transactionId: (json['transactionId'] as num?)?.toInt() ?? 0,
      transactionCode: json['transactionCode']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'out',
      amount: json['amount']?.toString() ?? '0',
      description: json['description']?.toString(),
      counterpartyAccountNumber: json['counterpartyAccountNumber']?.toString(),
      counterpartyAccountName: json['counterpartyAccountName']?.toString(),
      transactionType: json['transactionType']?.toString() ?? '',
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class ExpenseCategoryOption {
  final String categoryCode;
  final String categoryName;

  ExpenseCategoryOption({required this.categoryCode, required this.categoryName});

  factory ExpenseCategoryOption.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryOption(
      categoryCode: json['categoryCode']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
    );
  }
}

class ExpenseOverview {
  final String flowType;
  final String totalIncome;
  final String totalExpense;
  final String selectedFlowTotal;
  final int selectedFlowTransactionCount;
  final int unclassifiedTransactionCount;
  final List<ExpenseCategorySummary> categories;
  final List<UnclassifiedExpenseTransaction> unclassifiedTransactions;
  final List<MonthlyTrendItem> monthlyTrend;

  ExpenseOverview({
    required this.flowType,
    required this.totalIncome,
    required this.totalExpense,
    required this.selectedFlowTotal,
    required this.selectedFlowTransactionCount,
    required this.unclassifiedTransactionCount,
    required this.categories,
    required this.unclassifiedTransactions,
    required this.monthlyTrend,
  });

  factory ExpenseOverview.fromJson(Map<String, dynamic> json) {
    final categoriesRaw = json['categories'] as List<dynamic>? ?? const [];
    final unclassifiedRaw = json['unclassifiedTransactions'] as List<dynamic>? ?? const [];
    final trendRaw = (json['monthlyTrend'] ?? json['trend']) as List<dynamic>? ?? const [];
    return ExpenseOverview(
      flowType: json['flowType']?.toString() ?? 'out',
      totalIncome: json['totalIncome']?.toString() ?? '0',
      totalExpense: json['totalExpense']?.toString() ?? '0',
      selectedFlowTotal: json['selectedFlowTotal']?.toString() ?? '0',
      selectedFlowTransactionCount: (json['selectedFlowTransactionCount'] as num?)?.toInt() ?? 0,
      unclassifiedTransactionCount: (json['unclassifiedTransactionCount'] as num?)?.toInt() ?? 0,
      categories: categoriesRaw
          .map((e) => ExpenseCategorySummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      unclassifiedTransactions: unclassifiedRaw
          .map((e) => UnclassifiedExpenseTransaction.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      monthlyTrend: trendRaw
          .map((e) => MonthlyTrendItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class ExpenseApi {
  final AuthedApi _api;

  ExpenseApi({required AuthedApi api}) : _api = api;

  Future<ExpenseOverview> getOverview({String flowType = 'out'}) {
    return _api.getJson(
      '/api/mobile/expenses/overview',
      query: {'flowType': flowType},
      parser: (decoded) => ExpenseOverview.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<List<ExpenseCategoryOption>> getCategories({String flowType = 'out'}) {
    return _api.getJson(
      '/api/mobile/expenses/categories',
      query: {'flowType': flowType},
      parser: (decoded) {
        final list = (decoded as List).cast<Object?>();
        return list
            .map((e) => ExpenseCategoryOption.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }

  Future<void> classifyTransaction({
    required int transactionId,
    required String categoryCode,
    String flowType = 'out',
  }) {
    return _api.postJson(
      '/api/mobile/expenses/transactions/$transactionId/classify',
      body: {
        'categoryCode': categoryCode,
        'flowType': flowType,
        'source': 'mobile',
      },
      parser: (_) => null,
    );
  }

  Future<DailyRecommendation> getDailyRecommendation() {
    return _api.getJson(
      '/api/mobile/ai/recommendations/daily',
      parser: (decoded) => DailyRecommendation.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }
}
