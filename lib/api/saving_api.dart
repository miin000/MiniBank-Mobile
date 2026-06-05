import 'dart:convert';
import 'authed_api.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

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
  final double? bonusInterestRate;
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
    this.bonusInterestRate,
    required this.interestAccrualFrequency,
    required this.interestPostingFrequency,
    required this.capitalized,
    this.minOpenAmount,
    this.maxOpenAmount,
    required this.status,
  });

  factory SavingProduct.fromJson(Map<String, dynamic> json) => SavingProduct(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    currency: json['currency'] as String? ?? 'VND',
    termUnit: json['termUnit'] as String? ?? 'MONTH',
    termValue: json['termValue'] as int? ?? 0,
    interestRateType: json['interestRateType'] as String? ?? 'FIXED',
    baseInterestRate: (json['baseInterestRate'] as num?)?.toDouble() ?? 0,
    penaltyInterestRate: (json['penaltyInterestRate'] as num?)?.toDouble(),
    bonusInterestRate: (json['bonusInterestRate'] as num?)?.toDouble(),
    interestAccrualFrequency:
        json['interestAccrualFrequency'] as String? ?? 'MONTHLY',
    interestPostingFrequency:
        json['interestPostingFrequency'] as String? ?? 'END_OF_TERM',
    capitalized: json['capitalized'] as bool? ?? true,
    minOpenAmount: (json['minOpenAmount'] as num?)?.toDouble(),
    maxOpenAmount: (json['maxOpenAmount'] as num?)?.toDouble(),
    status: json['status'] as String? ?? 'active',
  );
}

class AccountSummary {
  final int id;
  final String accountNumber;
  final String accountName;
  final String accountType;
  final String currency;
  final double availableBalance;
  final String status;

  const AccountSummary({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.accountType,
    required this.currency,
    required this.availableBalance,
    required this.status,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) => AccountSummary(
    id: json['id'] as int,
    accountNumber: json['accountNumber'] as String? ?? '',
    accountName: json['accountName'] as String? ?? '',
    accountType: json['accountType'] as String? ?? 'payment',
    currency: json['currency'] as String? ?? 'VND',
    availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'active',
  );
}

/// Maps to backend SavingResponse record.
/// NOTE: backend SavingResponse does NOT include accruedInterestAmount,
/// postedInterestAmount, projectedMaturityAmount, interestRateType,
/// termUnit, termValue, capitalized, autoRenew fields on the list endpoint.
/// These come from the product, not the saving record directly.
/// We default them to safe values so the detail screen still works.
class SavingDetail {
  final int id;
  final String code;
  final int savingProductId;
  final String productName;
  final double principalAmount;
  final double actualInterestRate;
  final String interestRateType;
  final String termUnit;
  final int termValue;
  final bool capitalized;
  final double accruedInterestAmount;
  final double postedInterestAmount;
  final double? earnedInterestAmount;
  final double? projectedMaturityAmount;
  final bool autoRenew;
  final String status;
  final String? openDate;
  final String? maturityDate;
  final String? closeDate;

  const SavingDetail({
    required this.id,
    required this.code,
    required this.savingProductId,
    required this.productName,
    required this.principalAmount,
    required this.actualInterestRate,
    required this.interestRateType,
    required this.termUnit,
    required this.termValue,
    required this.capitalized,
    required this.accruedInterestAmount,
    required this.postedInterestAmount,
    this.earnedInterestAmount,
    this.projectedMaturityAmount,
    required this.autoRenew,
    required this.status,
    this.openDate,
    this.maturityDate,
    this.closeDate,
  });

  factory SavingDetail.fromJson(Map<String, dynamic> json) => SavingDetail(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    savingProductId: json['savingProductId'] as int? ?? 0,
    productName: json['productName'] as String? ?? '',
    principalAmount: (json['principalAmount'] as num?)?.toDouble() ?? 0,
    actualInterestRate: (json['actualInterestRate'] as num?)?.toDouble() ?? 0,
    interestRateType: json['interestRateType'] as String? ?? 'FIXED',
    termUnit: json['termUnit'] as String? ?? 'MONTH',
    termValue: json['termValue'] as int? ?? 0,
    capitalized: json['capitalized'] as bool? ?? true,
    accruedInterestAmount:
        (json['accruedInterestAmount'] as num?)?.toDouble() ?? 0,
    postedInterestAmount:
        (json['postedInterestAmount'] as num?)?.toDouble() ?? 0,
    earnedInterestAmount: (json['earnedInterestAmount'] as num?)?.toDouble()
        ?? (json['totalInterestEarned'] as num?)?.toDouble(),
    projectedMaturityAmount: (json['projectedMaturityAmount'] as num?)
        ?.toDouble(),
    autoRenew: json['autoRenew'] as bool? ?? false,
    status: json['status'] as String? ?? '',
    openDate: json['openDate'] as String?,
    maturityDate: json['maturityDate'] as String?,
    closeDate: json['closeDate'] as String?,
  );
}

class SavingOpenInitiateResponse {
  final int transactionId;
  final String transactionCode;
  final String status;
  final bool otpRequired;
  final String? debugOtp;

  const SavingOpenInitiateResponse({
    required this.transactionId,
    required this.transactionCode,
    required this.status,
    required this.otpRequired,
    required this.debugOtp,
  });

  factory SavingOpenInitiateResponse.fromJson(Map<String, dynamic> json) =>
      SavingOpenInitiateResponse(
        transactionId: (json['transactionId'] as num?)?.toInt() ?? 0,
        transactionCode: json['transactionCode']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        otpRequired: (json['otpRequired'] is bool)
            ? (json['otpRequired'] as bool)
            : (json['otpRequired']?.toString() == 'true'),
        debugOtp: json['debugOtp'] as String?,
      );
}

class SavingOpenConfirmResponse {
  final int transactionId;
  final String status;
  final int savingId;
  final String savingCode;

  const SavingOpenConfirmResponse({
    required this.transactionId,
    required this.status,
    required this.savingId,
    required this.savingCode,
  });

  factory SavingOpenConfirmResponse.fromJson(Map<String, dynamic> json) =>
      SavingOpenConfirmResponse(
        transactionId: (json['transactionId'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? '',
        savingId: (json['savingId'] as num?)?.toInt() ?? 0,
        savingCode: json['savingCode']?.toString() ?? '',
      );
}

/// Maps to backend SettlementRequestItem record:
/// id, requestCode, savingId, savingCode, customerId, customerName,
/// principalAmount, estimatedInterest, settlementAmount, settlementType,
/// status, statusLabel, settlementAccountNumber, reason,
/// submittedAt, processedAt, processNote
class SettlementRequest {
  final int id;
  final String requestCode;
  final int savingId;
  final String savingCode;
  final double principalAmount;
  final double estimatedInterest;
  final double settlementAmount;
  final String settlementType; // 'early' | 'maturity'
  final String status; // 'pending' | 'approved' | 'rejected'
  final String statusLabel;
  final String? settlementAccountNumber;
  final String? reason;
  final String? submittedAt;
  final String? processedAt;
  final String? processNote;

  const SettlementRequest({
    required this.id,
    required this.requestCode,
    required this.savingId,
    required this.savingCode,
    required this.principalAmount,
    required this.estimatedInterest,
    required this.settlementAmount,
    required this.settlementType,
    required this.status,
    required this.statusLabel,
    this.settlementAccountNumber,
    this.reason,
    this.submittedAt,
    this.processedAt,
    this.processNote,
  });

  factory SettlementRequest.fromJson(Map<String, dynamic> json) =>
      SettlementRequest(
        id: json['id'] as int,
        requestCode: json['requestCode'] as String? ?? '',
        savingId: json['savingId'] as int? ?? 0,
        savingCode: json['savingCode'] as String? ?? '',
        principalAmount: (json['principalAmount'] as num?)?.toDouble() ?? 0,
        estimatedInterest: (json['estimatedInterest'] as num?)?.toDouble() ?? 0,
        settlementAmount: (json['settlementAmount'] as num?)?.toDouble() ?? 0,
        settlementType: json['settlementType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        statusLabel: json['statusLabel'] as String? ?? '',
        settlementAccountNumber: json['settlementAccountNumber'] as String?,
        reason: json['reason'] as String?,
        submittedAt: json['submittedAt']?.toString(),
        processedAt: json['processedAt']?.toString(),
        processNote: json['processNote'] as String?,
      );
}

// ─── Request bodies ───────────────────────────────────────────────────────────

class CreateSavingRequest {
  final int savingProductId;
  final int sourceAccountId;
  final int? settlementAccountId;
  final String principalAmount;
  final bool autoRenew;
  final String interestPostingMode;
  final String? note;

  const CreateSavingRequest({
    required this.savingProductId,
    required this.sourceAccountId,
    this.settlementAccountId,
    required this.principalAmount,
    required this.autoRenew,
    required this.interestPostingMode,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'savingProductId': savingProductId,
    'sourceAccountId': sourceAccountId,
    if (settlementAccountId != null) 'settlementAccountId': settlementAccountId,
    'principalAmount': principalAmount,
    'autoRenew': autoRenew,
    'interestPostingMode': interestPostingMode,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

// ─── API ─────────────────────────────────────────────────────────────────────

class SavingApi {
  final AuthedApi _api;
  const SavingApi({required AuthedApi api}) : _api = api;

  /// GET /api/mobile/savings/products
  Future<List<SavingProduct>> getSavingProducts() async {
    final res = await _api.get('/api/mobile/savings/products');
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    final raw = decoded is List
        ? List<dynamic>.from(decoded)
        : ((decoded as Map<String, dynamic>)['data'] as List<dynamic>? ??
              decoded['content'] as List<dynamic>? ??
              (decoded['data'] is List
                  ? List<dynamic>.from(decoded['data'] as List)
                  : [decoded]));
    return raw
        .map((e) => SavingProduct.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// GET /api/accounts/me
  Future<List<AccountSummary>> getMyAccounts() async {
    final res = await _api.get('/api/accounts/me');
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = _extractList(body);
    return list
        .map((e) => AccountSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/mobile/savings
  Future<List<SavingDetail>> getMySavings() async {
    final res = await _api.get('/api/mobile/savings');
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    final list = _extractList(decoded);
    return list
        .map((e) => SavingDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/mobile/savings/{id}
  Future<SavingDetail> getSavingById(int id) async {
    final res = await _api.get('/api/mobile/savings/$id');
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    return SavingDetail.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// POST /api/mobile/savings — create saving (old flow, no OTP)
  Future<SavingDetail> createSaving({
    required int savingProductId,
    required int sourceAccountId,
    int? settlementAccountId,
    required String principalAmount,
    bool autoRenew = false,
    String interestPostingMode = 'END_OF_TERM',
    String? note,
  }) async {
    final request = CreateSavingRequest(
      savingProductId: savingProductId,
      sourceAccountId: sourceAccountId,
      settlementAccountId: settlementAccountId,
      principalAmount: principalAmount,
      autoRenew: autoRenew,
      interestPostingMode: interestPostingMode,
      note: note,
    );
    final res = await _api.post(
      '/api/mobile/savings',
      body: jsonEncode(request.toJson()),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return SavingDetail.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// POST /api/mobile/savings/open/initiate
  Future<SavingOpenInitiateResponse> initiateOpenSaving({
    required int savingProductId,
    required int sourceAccountId,
    int? settlementAccountId,
    required String principalAmount,
    bool autoRenew = false,
    required bool agreementAccepted,
    String? agreementVersion,
  }) async {
    final res = await _api.postJson(
      '/api/mobile/savings/open/initiate',
      body: {
        'savingProductId': savingProductId,
        'sourceAccountId': sourceAccountId,
        if (settlementAccountId != null)
          'settlementAccountId': settlementAccountId,
        'autoRenew': autoRenew,
        'principalAmount': principalAmount,
        'agreementAccepted': agreementAccepted,
        if (agreementVersion != null) 'agreementVersion': agreementVersion,
      },
      parser: (decoded) => SavingOpenInitiateResponse.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      ),
    );
    return res;
  }

  /// POST /api/mobile/savings/open/confirm
  Future<SavingOpenConfirmResponse> confirmOpenSaving({
    required int transactionId,
    required String otpCode,
  }) async {
    final res = await _api.postJson(
      '/api/mobile/savings/open/confirm',
      body: {'transactionId': transactionId, 'otpCode': otpCode},
      parser: (decoded) => SavingOpenConfirmResponse.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      ),
    );
    return res;
  }

  /// PATCH /api/mobile/savings/{id}/auto-renew
  Future<void> setAutoRenew(int id, {required bool autoRenew}) async {
    final res = await _api.patch(
      '/api/mobile/savings/$id/auto-renew',
      body: jsonEncode({'autoRenew': autoRenew}),
    );
    _checkStatus(res);
  }

  // ─── Settlement (tất toán sớm) ───────────────────────────────────────────

  /// GET /api/mobile/savings/settlement-requests
  /// Lists settlement requests submitted by the current user.
  Future<List<SettlementRequest>> getMySettlementRequests() async {
    final res = await _api.get('/api/mobile/savings/settlement-requests');
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    final list = _extractList(decoded);
    return list
        .map((e) => SettlementRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/mobile/savings/settlement-requests
  /// Submits an early settlement (tất toán sớm) request for [savingId].
  /// [settlementAccountId] is optional — backend falls back to the saving's
  /// source account when omitted.
  /// [reason] is optional free-text.
  Future<SettlementRequest> requestEarlySettlement({
    required int savingId,
    int? settlementAccountId,
    String? reason,
  }) async {
    final body = <String, dynamic>{'savingId': savingId};
    if (settlementAccountId != null) {
      body['settlementAccountId'] = settlementAccountId;
    }
    if (reason != null && reason.isNotEmpty) {
      body['reason'] = reason;
    }
    final res = await _api.post(
      '/api/mobile/savings/settlement-requests',
      body: jsonEncode(body),
    );
    _checkStatus(res);
    final decoded = jsonDecode(res.body);
    final map = decoded is Map<String, dynamic>
        ? (decoded['data'] as Map<String, dynamic>? ?? decoded)
        : decoded as Map<String, dynamic>;
    return SettlementRequest.fromJson(map);
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  List<dynamic> _extractList(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) return decoded['data'] as List<dynamic>;
      if (decoded['content'] is List)
        return decoded['content'] as List<dynamic>;
      if (decoded['items'] is List) return decoded['items'] as List<dynamic>;
    }
    return [];
  }

  void _checkStatus(dynamic res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Lỗi ${res.statusCode}';
      try {
        final b = jsonDecode(res.body as String) as Map<String, dynamic>;
        msg = b['message'] as String? ?? b['error'] as String? ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }
}

// ─── Backwards-compatible simple Saving model ────────────────────────────────

class Saving {
  final int id;
  final String code;
  final String productName;
  final String principalAmount;
  final double actualInterestRate;
  final int termValue;
  final String accruedInterestAmount;
  final String postedInterestAmount;
  final String earnedInterestAmount;
  final String status;
  final String interestAccrualFrequency;
  final String interestPostingFrequency;
  final String? openDate;
  final String? maturityDate;
  final String? projectedMaturityAmount;

  Saving({
    required this.id,
    required this.code,
    required this.productName,
    required this.principalAmount,
    required this.actualInterestRate,
    required this.termValue,
    required this.accruedInterestAmount,
    required this.postedInterestAmount,
    required this.earnedInterestAmount,
    required this.status,
    required this.interestAccrualFrequency,
    required this.interestPostingFrequency,
    this.openDate,
    this.maturityDate,
    this.projectedMaturityAmount,
  });

  static double _computedEarnedInterest(SavingDetail d) {
    final explicit = d.earnedInterestAmount ?? d.postedInterestAmount + d.accruedInterestAmount;
    if (explicit > 0) return explicit;
    final open = d.openDate == null ? null : DateTime.tryParse(d.openDate!);
    if (open == null || d.principalAmount <= 0 || d.actualInterestRate <= 0) return explicit;
    final maturity = d.maturityDate == null ? null : DateTime.tryParse(d.maturityDate!);
    final now = DateTime.now();
    final end = maturity != null && now.isAfter(maturity) ? maturity : now;
    final days = end.difference(open).inDays;
    if (days <= 0) return explicit;
    return d.principalAmount * (d.actualInterestRate / 100) * days / 365;
  }

  factory Saving.fromDetail(SavingDetail d) => Saving(
    id: d.id,
    code: d.code,
    productName: d.productName,
    principalAmount: d.principalAmount.toStringAsFixed(0),
    actualInterestRate: d.actualInterestRate,
    termValue: d.termValue,
    accruedInterestAmount: d.accruedInterestAmount.toStringAsFixed(0),
    postedInterestAmount: d.postedInterestAmount.toStringAsFixed(0),
    earnedInterestAmount: _computedEarnedInterest(d).toStringAsFixed(0),
    status: d.status,
    interestAccrualFrequency: 'MONTHLY',
    interestPostingFrequency: 'END_OF_TERM',
    openDate: d.openDate,
    maturityDate: d.maturityDate,
    projectedMaturityAmount: d.projectedMaturityAmount?.toStringAsFixed(0),
  );
}

extension SavingApiCompat on SavingApi {
  Future<List<Saving>> getSavings() async {
    final details = await getMySavings();
    return details.map((d) => Saving.fromDetail(d)).toList();
  }

  Future<Saving> getSaving(int id) async {
    final detail = await getSavingById(id);
    return Saving.fromDetail(detail);
  }
}
