import '../auth/auth_storage.dart';
import 'authed_api.dart';

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

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as int? ?? 0,
      code: json['code']?.toString() ?? '',
      approvedAmount: json['approvedAmount']?.toString() ?? '0',
      disbursedAmount: json['disbursedAmount']?.toString() ?? '0',
      outstandingPrincipal: json['outstandingPrincipal']?.toString() ?? '0',
      outstandingInterest: json['outstandingInterest']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      repaymentFrequency: json['repaymentFrequency']?.toString() ?? '',
      termMonths: json['termMonths'] as int? ?? 0,
      nextDueDate: json['nextDueDate']?.toString(),
      maturityDate: json['maturityDate']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class LoanApi {
  final AuthedApi api;

  LoanApi({required this.api});

  Future<List<Loan>> getLoans() async {
    final list = await api.getJson<List>(
      '/api/mobile/loans',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list.map((item) => Loan.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Loan> getLoan(int id) async {
    return await api.getJson<Loan>(
      '/api/mobile/loans/$id',
      parser: (decoded) {
        if (decoded == null) throw Exception('Loan not found');
        return Loan.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<Loan> createLoan({
    required int loanProductId,
    required int disbursementAccountId,
    required int repaymentAccountId,
    required String amount,
    required String purpose,
  }) async {
    return await api.postJson<Loan>(
      '/api/mobile/loans',
      body: {
        'loanProductId': loanProductId,
        'disbursementAccountId': disbursementAccountId,
        'repaymentAccountId': repaymentAccountId,
        'amount': amount,
        'purpose': purpose,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Failed to create loan');
        return Loan.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }
}
