import 'authed_api.dart';

class SavingProduct {
  final int id;
  final String code;
  final String name;
  final String currency;
  final String termUnit;
  final int termValue;
  final String interestRateType;
  final double baseInterestRate;
  final double? penaltyInterestRate;
  final String interestAccrualFrequency;
  final String interestPostingFrequency;
  final bool capitalized;
  final double? minOpenAmount;
  final double? maxOpenAmount;
  final String status;

  const SavingProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.currency,
    required this.termUnit,
    required this.termValue,
    required this.interestRateType,
    required this.baseInterestRate,
    this.penaltyInterestRate,
    required this.interestAccrualFrequency,
    required this.interestPostingFrequency,
    required this.capitalized,
    this.minOpenAmount,
    this.maxOpenAmount,
    required this.status,
  });

  factory SavingProduct.fromJson(Map<String, dynamic> json) {
    return SavingProduct(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      termUnit: json['termUnit']?.toString() ?? '',
      termValue: json['termValue'] as int? ?? 0,
      interestRateType: json['interestRateType']?.toString() ?? '',
      baseInterestRate: (json['baseInterestRate'] as num?)?.toDouble() ?? 0,
      penaltyInterestRate: (json['penaltyInterestRate'] as num?)?.toDouble(),
      interestAccrualFrequency:
          json['interestAccrualFrequency']?.toString() ?? '',
      interestPostingFrequency:
          json['interestPostingFrequency']?.toString() ?? '',
      capitalized: json['capitalized'] as bool? ?? false,
      minOpenAmount: (json['minOpenAmount'] as num?)?.toDouble(),
      maxOpenAmount: (json['maxOpenAmount'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? '',
    );
  }
}

class Saving {
  final int id;
  final String code;
  final String principalAmount;
  final String accruedInterestAmount;
  final String postedInterestAmount;
  final String status;
  final String interestAccrualFrequency;
  final String interestPostingFrequency;
  final String? openDate;
  final String? maturityDate;
  final String? projectedMaturityAmount;

  Saving({
    required this.id,
    required this.code,
    required this.principalAmount,
    required this.accruedInterestAmount,
    required this.postedInterestAmount,
    required this.status,
    required this.interestAccrualFrequency,
    required this.interestPostingFrequency,
    this.openDate,
    this.maturityDate,
    this.projectedMaturityAmount,
  });

  factory Saving.fromJson(Map<String, dynamic> json) {
    return Saving(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      principalAmount: json['principalAmount']?.toString() ?? '0',
      accruedInterestAmount: json['accruedInterestAmount']?.toString() ?? '0',
      postedInterestAmount: json['postedInterestAmount']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      interestAccrualFrequency: json['interestAccrualFrequency']?.toString() ?? '',
      interestPostingFrequency: json['interestPostingFrequency']?.toString() ?? '',
      openDate: json['openDate']?.toString(),
      maturityDate: json['maturityDate']?.toString(),
      projectedMaturityAmount: json['projectedMaturityAmount']?.toString(),
    );
  }
}

class AccountSummary {
  final int id;
  final String accountNumber;
  final String accountName;
  final String accountType;
  final double availableBalance;
  final String currency;
  final String status;

  const AccountSummary({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.accountType,
    required this.availableBalance,
    required this.currency,
    required this.status,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      id: json['id'] as int? ?? 0,
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? '',
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class SavingApi {
  final AuthedApi api;

  SavingApi({required this.api});

  Future<List<SavingProduct>> getSavingProducts() async {
    final list = await api.getJson<List>(
      '/api/mobile/savings/products',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list
        .map((item) => SavingProduct.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Saving>> getSavings() async {
    final list = await api.getJson<List>(
      '/api/mobile/savings',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list.map((item) => Saving.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Saving> getSaving(int id) async {
    return await api.getJson<Saving>(
      '/api/mobile/savings/$id',
      parser: (decoded) {
        if (decoded == null) throw Exception('Saving not found');
        return Saving.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<Saving> createSaving({
    required int savingProductId,
    required int sourceAccountId,
    required String principalAmount,
    int? settlementAccountId,
    bool? autoRenew,
  }) async {
    return await api.postJson<Saving>(
      '/api/mobile/savings',
      body: {
        'savingProductId': savingProductId,
        'sourceAccountId': sourceAccountId,
        'principalAmount': principalAmount,
        if (settlementAccountId != null) 'settlementAccountId': settlementAccountId,
        if (autoRenew != null) 'autoRenew': autoRenew,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Failed to create saving');
        return Saving.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<List<AccountSummary>> getMyAccounts() async {
    final list = await api.getJson<List>(
      '/api/mobile/accounts',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list
        .map((item) => AccountSummary.fromJson(item as Map<String, dynamic>))
        .where((account) => account.status.toLowerCase() == 'active')
        .toList();
  }
}
