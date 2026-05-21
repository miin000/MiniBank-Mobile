import 'dart:convert';
import 'authed_api.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class LoanProduct {
  final int    id;
  final String code;
  final String name;
  final String loanType;           // PERSONAL | BUSINESS | MORTGAGE
  final String currency;
  final double minAmount;
  final double maxAmount;
  final int    minTermMonths;
  final int    maxTermMonths;
  final String interestRateType;
  final double baseInterestRate;
  final double? penaltyInterestRate;
  final String interestCalculationMethod;
  final String repaymentFrequency;
  final String status;

  const LoanProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.loanType,
    required this.currency,
    required this.minAmount,
    required this.maxAmount,
    required this.minTermMonths,
    required this.maxTermMonths,
    required this.interestRateType,
    required this.baseInterestRate,
    this.penaltyInterestRate,
    required this.interestCalculationMethod,
    required this.repaymentFrequency,
    required this.status,
  });

  factory LoanProduct.fromJson(Map<String, dynamic> json) => LoanProduct(
    id                        : json['id'] as int,
    code                      : json['code'] as String? ?? '',
    name                      : json['name'] as String? ?? '',
    loanType                  : json['loanType'] as String? ?? 'PERSONAL',
    currency                  : json['currency'] as String? ?? 'VND',
    minAmount                 : (json['minAmount'] as num?)?.toDouble() ?? 0,
    maxAmount                 : (json['maxAmount'] as num?)?.toDouble() ?? 0,
    minTermMonths             : json['minTermMonths'] as int? ?? 1,
    maxTermMonths             : json['maxTermMonths'] as int? ?? 60,
    interestRateType          : json['interestRateType'] as String? ?? 'FIXED',
    baseInterestRate          : (json['baseInterestRate'] as num?)?.toDouble() ?? 0,
    penaltyInterestRate       : (json['penaltyInterestRate'] as num?)?.toDouble(),
    interestCalculationMethod : json['interestCalculationMethod'] as String? ?? 'REDUCING_BALANCE',
    repaymentFrequency        : json['repaymentFrequency'] as String? ?? 'MONTHLY',
    status                    : json['status'] as String? ?? 'active',
  );
}

class LoanApplication {
  final int    id;
  final int    userId;
  final int?   loanProductId;
  final double requestedAmount;
  final int    requestedTermMonths;
  final double? monthlyIncome;
  final String? purpose;
  final String? collateralDescription;
  final String? priorityTag;
  final String status;             // pending | approved | rejected | more_info_needed
  final String submittedAt;
  final String? reviewedAt;
  final String? reviewNote;

  const LoanApplication({
    required this.id,
    required this.userId,
    this.loanProductId,
    required this.requestedAmount,
    required this.requestedTermMonths,
    this.monthlyIncome,
    this.purpose,
    this.collateralDescription,
    this.priorityTag,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewNote,
  });

  factory LoanApplication.fromJson(Map<String, dynamic> json) => LoanApplication(
    id                   : json['id'] as int,
    userId               : json['userId'] as int? ?? 0,
    loanProductId        : json['loanProductId'] as int?,
    requestedAmount      : (json['requestedAmount'] as num?)?.toDouble() ?? 0,
    requestedTermMonths  : json['requestedTermMonths'] as int? ?? 0,
    monthlyIncome        : (json['monthlyIncome'] as num?)?.toDouble(),
    purpose              : json['purpose'] as String?,
    collateralDescription: json['collateralDescription'] as String?,
    priorityTag          : json['priorityTag'] as String?,
    status               : json['status'] as String? ?? 'pending',
    submittedAt          : json['submittedAt'] as String? ?? '',
    reviewedAt           : json['reviewedAt'] as String?,
    reviewNote           : json['reviewNote'] as String?,
  );
}

class LoanRepaymentScheduleItem {
  final int    id;
  final int    loanId;
  final int    installmentNo;
  final String dueDate;
  final double openingPrincipalBalance;
  final double principalDue;
  final double interestRate;
  final double interestDue;
  final double penaltyInterestDue;
  final double feeDue;
  final double totalDue;
  final double principalPaid;
  final double interestPaid;
  final String status;             // unpaid | partial | paid | overdue
  final String? paidAt;

  const LoanRepaymentScheduleItem({
    required this.id,
    required this.loanId,
    required this.installmentNo,
    required this.dueDate,
    required this.openingPrincipalBalance,
    required this.principalDue,
    required this.interestRate,
    required this.interestDue,
    required this.penaltyInterestDue,
    required this.feeDue,
    required this.totalDue,
    required this.principalPaid,
    required this.interestPaid,
    required this.status,
    this.paidAt,
  });

  factory LoanRepaymentScheduleItem.fromJson(Map<String, dynamic> json) =>
      LoanRepaymentScheduleItem(
        id                     : json['id'] as int,
        loanId                 : json['loanId'] as int? ?? 0,
        installmentNo          : json['installmentNo'] as int? ?? 0,
        dueDate                : json['dueDate'] as String? ?? '',
        openingPrincipalBalance: (json['openingPrincipalBalance'] as num?)?.toDouble() ?? 0,
        principalDue           : (json['principalDue'] as num?)?.toDouble() ?? 0,
        interestRate           : (json['interestRate'] as num?)?.toDouble() ?? 0,
        interestDue            : (json['interestDue'] as num?)?.toDouble() ?? 0,
        penaltyInterestDue     : (json['penaltyInterestDue'] as num?)?.toDouble() ?? 0,
        feeDue                 : (json['feeDue'] as num?)?.toDouble() ?? 0,
        totalDue               : (json['totalDue'] as num?)?.toDouble() ?? 0,
        principalPaid          : (json['principalPaid'] as num?)?.toDouble() ?? 0,
        interestPaid           : (json['interestPaid'] as num?)?.toDouble() ?? 0,
        status                 : json['status'] as String? ?? 'unpaid',
        paidAt                 : json['paidAt'] as String?,
      );
}

class LoanDetail {
  final int    id;
  final String code;
  final int    loanApplicationId;
  final int    userId;
  final int?   loanProductId;
  final int?   disbursementAccountId;
  final int?   repaymentAccountId;
  final double approvedAmount;
  final double disbursedAmount;
  final double actualInterestRate;
  final String interestCalculationMethod;
  final String repaymentFrequency;
  final int    termMonths;
  final double outstandingPrincipal;
  final double outstandingInterest;
  final double overduePrincipal;
  final double overdueInterest;
  final String status;
  final String? disbursedAt;
  final String? nextDueDate;
  final String? closedAt;
  final String  createdAt;
  final List<LoanRepaymentScheduleItem> schedule;

  const LoanDetail({
    required this.id,
    required this.code,
    required this.loanApplicationId,
    required this.userId,
    this.loanProductId,
    this.disbursementAccountId,
    this.repaymentAccountId,
    required this.approvedAmount,
    required this.disbursedAmount,
    required this.actualInterestRate,
    required this.interestCalculationMethod,
    required this.repaymentFrequency,
    required this.termMonths,
    required this.outstandingPrincipal,
    required this.outstandingInterest,
    required this.overduePrincipal,
    required this.overdueInterest,
    required this.status,
    this.disbursedAt,
    this.nextDueDate,
    this.closedAt,
    required this.createdAt,
    this.schedule = const [],
  });

  factory LoanDetail.fromJson(Map<String, dynamic> json) => LoanDetail(
    id                        : json['id'] as int,
    code                      : json['code'] as String? ?? '',
    loanApplicationId         : json['loanApplicationId'] as int? ?? 0,
    userId                    : json['userId'] as int? ?? 0,
    loanProductId             : json['loanProductId'] as int?,
    disbursementAccountId     : json['disbursementAccountId'] as int?,
    repaymentAccountId        : json['repaymentAccountId'] as int?,
    approvedAmount            : (json['approvedAmount'] as num?)?.toDouble() ?? 0,
    disbursedAmount           : (json['disbursedAmount'] as num?)?.toDouble() ?? 0,
    actualInterestRate        : (json['actualInterestRate'] as num?)?.toDouble() ?? 0,
    interestCalculationMethod : json['interestCalculationMethod'] as String? ?? 'REDUCING_BALANCE',
    repaymentFrequency        : json['repaymentFrequency'] as String? ?? 'MONTHLY',
    termMonths                : json['termMonths'] as int? ?? 0,
    outstandingPrincipal      : (json['outstandingPrincipal'] as num?)?.toDouble() ?? 0,
    outstandingInterest       : (json['outstandingInterest'] as num?)?.toDouble() ?? 0,
    overduePrincipal          : (json['overduePrincipal'] as num?)?.toDouble() ?? 0,
    overdueInterest           : (json['overdueInterest'] as num?)?.toDouble() ?? 0,
    status                    : json['status'] as String? ?? '',
    disbursedAt               : json['disbursedAt'] as String?,
    nextDueDate               : json['nextDueDate'] as String?,
    closedAt                  : json['closedAt'] as String?,
    createdAt                 : json['createdAt'] as String? ?? '',
    schedule                  : (json['schedule'] as List<dynamic>?)
        ?.map((e) => LoanRepaymentScheduleItem.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}

// ─── Request bodies ───────────────────────────────────────────────────────────

class LoanApplicationRequest {
  final int    loanProductId;
  final int    disbursementAccountId;
  final int    repaymentAccountId;
  final String requestedAmount;
  final int    requestedTermMonths;
  final String purpose;
  final String loanType;               // unsecured | secured
  final String? monthlyIncome;
  final String? collateralDescription;
  final double? collateralEstimatedValue;
  final String? incomeProofUrl;
  final String? collateralProofUrl;
  final String? bankStatementUrl;
  final String? workCertUrl;

  // Personal supplement fields
  final String? maritalStatus;
  final int?    numberOfDependents;
  final String? education;
  final String? occupation;
  final String? workDuration;
  final String? housingStatus;
  final String? mailingAddress;

  const LoanApplicationRequest({
    required this.loanProductId,
    required this.disbursementAccountId,
    required this.repaymentAccountId,
    required this.requestedAmount,
    required this.requestedTermMonths,
    required this.purpose,
    required this.loanType,
    this.monthlyIncome,
    this.collateralDescription,
    this.collateralEstimatedValue,
    this.incomeProofUrl,
    this.collateralProofUrl,
    this.bankStatementUrl,
    this.workCertUrl,
    this.maritalStatus,
    this.numberOfDependents,
    this.education,
    this.occupation,
    this.workDuration,
    this.housingStatus,
    this.mailingAddress,
  });

  Map<String, dynamic> toJson() => {
    'loanProductId'              : loanProductId,
    'disbursementAccountId'      : disbursementAccountId,
    'repaymentAccountId'         : repaymentAccountId,
    'amount'                     : requestedAmount,
    'termMonths'                 : requestedTermMonths,
    'purpose'                    : purpose,
    'loanType'                   : loanType,
    if (monthlyIncome != null)              'monthlyIncome'            : monthlyIncome,
    if (collateralDescription != null)      'collateralDescription'    : collateralDescription,
    if (collateralEstimatedValue != null)   'collateralEstimatedValue' : collateralEstimatedValue,
    if (incomeProofUrl != null)             'incomeProofUrl'           : incomeProofUrl,
    if (collateralProofUrl != null)         'collateralProofUrl'       : collateralProofUrl,
    if (bankStatementUrl != null)           'bankStatementUrl'         : bankStatementUrl,
    if (workCertUrl != null)                'workCertUrl'              : workCertUrl,
    if (maritalStatus != null)              'maritalStatus'            : maritalStatus,
    if (numberOfDependents != null)         'numberOfDependents'       : numberOfDependents,
    if (education != null)                  'education'                : education,
    if (occupation != null)                 'occupation'               : occupation,
    if (workDuration != null)               'workDuration'             : workDuration,
    if (housingStatus != null)              'housingStatus'            : housingStatus,
    if (mailingAddress != null && mailingAddress!.isNotEmpty)
                                            'mailingAddress'           : mailingAddress,
  };
}

// ─── API ─────────────────────────────────────────────────────────────────────

class LoanApi {
  final AuthedApi _api;
  const LoanApi({required AuthedApi api}) : _api = api;

  /// GET /api/loan-products?status=active
  Future<List<LoanProduct>> getLoanProducts() async {
    final res = await _api.get('/api/mobile/loan-products?status=active');
    _check(res);
    final decoded = jsonDecode(res.body);
    final raw = decoded is List
        ? List<dynamic>.from(decoded)
        : _list(decoded as Map<String, dynamic>);
    return raw
        .map((e) => LoanProduct.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// GET /api/loan-applications  — current user's applications
  Future<List<LoanApplication>> getMyApplications() async {
    final res = await _api.get('/api/mobile/loans/applications');
    _check(res);
    final decoded = jsonDecode(res.body);
    return _list(decoded)
      .map((e) => LoanApplication.fromJson(e as Map<String, dynamic>))
      .toList();
  }

  /// GET /api/loans  — active loans for current user
  Future<List<LoanDetail>> getMyLoans() async {
    final res = await _api.get('/api/mobile/loans');
    _check(res);
    final decoded = jsonDecode(res.body);
    return _list(decoded)
      .map((e) => LoanDetail.fromJson(e as Map<String, dynamic>))
      .toList();
  }

  /// GET /api/loans/{id}
  Future<LoanDetail> getLoanById(int id) async {
    final res = await _api.get('/api/mobile/loans/$id');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return LoanDetail.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// GET /api/loans/{id}/schedule
  Future<List<LoanRepaymentScheduleItem>> getRepaymentSchedule(int loanId) async {
    final res = await _api.get('/api/loans/$loanId/schedule');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _list(body)
        .map((e) => LoanRepaymentScheduleItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/loan-applications  — submit a new loan application
  Future<LoanApplication> applyForLoan({
    required int    loanProductId,
    required int    disbursementAccountId,
    required int    repaymentAccountId,
    required String amount,
    required int    termMonths,
    required String purpose,
    String          loanType              = 'unsecured',
    String?         monthlyIncome,
    String?         collateralDescription,
    double?         collateralEstimatedValue,
    String?         incomeProofUrl,
    String?         collateralProofUrl,
    String?         bankStatementUrl,
    String?         workCertUrl,
    String?         maritalStatus,
    int?            numberOfDependents,
    String?         education,
    String?         occupation,
    String?         workDuration,
    String?         housingStatus,
    String?         mailingAddress,
  }) async {
    final req = LoanApplicationRequest(
      loanProductId            : loanProductId,
      disbursementAccountId    : disbursementAccountId,
      repaymentAccountId       : repaymentAccountId,
      requestedAmount          : amount,
      requestedTermMonths      : termMonths,
      purpose                  : purpose,
      loanType                 : loanType,
      monthlyIncome            : monthlyIncome,
      collateralDescription    : collateralDescription,
      collateralEstimatedValue : collateralEstimatedValue,
      incomeProofUrl           : incomeProofUrl,
      collateralProofUrl       : collateralProofUrl,
      bankStatementUrl         : bankStatementUrl,
      workCertUrl              : workCertUrl,
      maritalStatus            : maritalStatus,
      numberOfDependents       : numberOfDependents,
      education                : education,
      occupation               : occupation,
      workDuration             : workDuration,
      housingStatus            : housingStatus,
      mailingAddress           : mailingAddress,
    );
    final res = await _api.post('/api/mobile/loans/applications', body: jsonEncode(req.toJson()));
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return LoanApplication.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  // ─── helpers ────────────────────────────────────────────────────────────
  List<dynamic> _list(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is List) return decoded['data'] as List;
      if (decoded['content'] is List) return decoded['content'] as List;
      if (decoded['items'] is List) return decoded['items'] as List;
    }
    return [];
  }

  void _check(dynamic res) {
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

// ----------------- Backwards-compatible simple Loan model -----------------
class Loan {
  final int id;
  final String code;
  final String approvedAmount;
  final String disbursedAmount;
  final String outstandingPrincipal;
  final String outstandingInterest;
  final String status;
  final String repaymentFrequency;
  final int termMonths;
  final String? nextDueDate;
  final String? maturityDate;
  final String createdAt;

  Loan({
    required this.id,
    required this.code,
    required this.approvedAmount,
    required this.disbursedAmount,
    required this.outstandingPrincipal,
    required this.outstandingInterest,
    required this.status,
    required this.repaymentFrequency,
    required this.termMonths,
    this.nextDueDate,
    this.maturityDate,
    required this.createdAt,
  });

  factory Loan.fromDetail(LoanDetail d) => Loan(
    id: d.id,
    code: d.code,
    approvedAmount: d.approvedAmount.toStringAsFixed(0),
    disbursedAmount: d.disbursedAmount.toStringAsFixed(0),
    outstandingPrincipal: d.outstandingPrincipal.toStringAsFixed(0),
    outstandingInterest: d.outstandingInterest.toStringAsFixed(0),
    status: d.status,
    repaymentFrequency: d.repaymentFrequency,
    termMonths: d.termMonths,
    nextDueDate: d.nextDueDate,
    maturityDate: d.closedAt,
    createdAt: d.createdAt,
  );
}

extension LoanApiCompat on LoanApi {
  Future<List<Loan>> getLoans() async {
    final details = await getMyLoans();
    return details.map((d) => Loan.fromDetail(d)).toList();
  }

  Future<Loan> getLoan(int id) async {
    final detail = await getLoanById(id);
    return Loan.fromDetail(detail);
  }
}
