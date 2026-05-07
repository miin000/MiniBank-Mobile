import '../auth/auth_storage.dart';
import 'authed_api.dart';

class TransferInitiateResponse {
  final int transactionId;
  final String transactionCode;
  final String status;
  final String fromAccountNumber;
  final String toAccountNumber;
  final String toAccountName;
  final String amount;
  final bool otpRequired;
  final bool pinRequired;
  final String? debugOtp;

  TransferInitiateResponse({
    required this.transactionId,
    required this.transactionCode,
    required this.status,
    required this.fromAccountNumber,
    required this.toAccountNumber,
    required this.toAccountName,
    required this.amount,
    required this.otpRequired,
    required this.pinRequired,
    required this.debugOtp,
  });

  factory TransferInitiateResponse.fromJson(Map<String, dynamic> json) {
    return TransferInitiateResponse(
      transactionId: (json['transactionId'] as num?)?.toInt() ?? 0,
      transactionCode: json['transactionCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      fromAccountNumber: json['fromAccountNumber']?.toString() ?? '',
      toAccountNumber: json['toAccountNumber']?.toString() ?? '',
      toAccountName: json['toAccountName']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '',
        otpRequired: (json['otpRequired'] is bool)
          ? (json['otpRequired'] as bool)
          : (json['otpRequired']?.toString() == 'true'),
        pinRequired: (json['pinRequired'] is bool)
          ? (json['pinRequired'] as bool)
          : (json['pinRequired']?.toString() == 'true'),
      debugOtp: json['debugOtp'] as String?,
    );
  }
}

class TransferConfirmResponse {
  final int transactionId;
  final String status;
  final String? completedAt;
  final String fromAccountNumber;
  final String toAccountNumber;
  final String amount;
  final String? fromAvailableBalance;

  TransferConfirmResponse({
    required this.transactionId,
    required this.status,
    required this.completedAt,
    required this.fromAccountNumber,
    required this.toAccountNumber,
    required this.amount,
    required this.fromAvailableBalance,
  });

  factory TransferConfirmResponse.fromJson(Map<String, dynamic> json) {
    return TransferConfirmResponse(
      transactionId: (json['transactionId'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      completedAt: json['completedAt'] as String?,
      fromAccountNumber: json['fromAccountNumber']?.toString() ?? '',
      toAccountNumber: json['toAccountNumber']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      fromAvailableBalance: json['fromAvailableBalance']?.toString(),
    );
  }
}

class TransferApi {
  final AuthedApi _api;

  TransferApi({required String baseUrl, required AuthStorage storage})
      : _api = AuthedApi(baseUrl: baseUrl, storage: storage);

  Future<TransferInitiateResponse> initiate({
    required String fromAccountNumber,
    required String toAccountNumber,
    required String amount,
    String? description,
    String? idempotencyKey,
    required String signatureBase64,
    required String pin,
  }) async {
    return _api.postJson(
      '/api/mobile/transfers/initiate',
      body: {
        'fromAccountNumber': fromAccountNumber,
        'toAccountNumber': toAccountNumber,
        'amount': amount,
        'description': description,
        'idempotencyKey': idempotencyKey,
        'signature': signatureBase64,
        'pin': pin,
      },
      parser: (decoded) => TransferInitiateResponse.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<TransferConfirmResponse> confirm({
    required int transactionId,
    required String otpCode,
  }) async {
    return _api.postJson(
      '/api/mobile/transfers/confirm',
      body: {
        'transactionId': transactionId,
        'otpCode': otpCode,
      },
      parser: (decoded) => TransferConfirmResponse.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }
}
