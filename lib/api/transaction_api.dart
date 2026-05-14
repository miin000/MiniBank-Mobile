import '../auth/auth_storage.dart';
import 'authed_api.dart';

class TransactionSummary {
  final int id;
  final String direction;
  final String amount;
  final String? description;
  final String? counterpartyAccountNumber;
  final String? counterpartyName;
  final String transactionType;
  final String status;
  final String createdAt;

  TransactionSummary({
    required this.id,
    required this.direction,
    required this.amount,
    required this.description,
    required this.counterpartyAccountNumber,
    required this.counterpartyName,
    required this.transactionType,
    required this.status,
    required this.createdAt,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      direction: json['direction']?.toString() ?? 'out',
      amount: json['amount']?.toString() ?? '0',
      description: json['description'] as String?,
      counterpartyAccountNumber: json['counterpartyAccountNumber']?.toString(),
      counterpartyName: json['counterpartyName']?.toString(),
      transactionType: json['transactionType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class TransactionApi {
  final AuthedApi _api;

  TransactionApi({required String baseUrl, required AuthStorage storage})
      : _api = AuthedApi(baseUrl: baseUrl, storage: storage);

  Future<List<TransactionSummary>> recent({int limit = 5}) async {
    return _api.getJson(
      '/api/mobile/transactions/recent',
      query: {'limit': '$limit'},
      parser: (decoded) {
        final list = (decoded as List).cast<Object?>();
        return list
            .map((e) => TransactionSummary.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }

  Future<List<TransactionSummary>> history({
    int limit = 20,
    int page = 0,
    String direction = 'all',
    String? status,
    String? query,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'page': '$page',
      'direction': direction,
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }

    return _api.getJson(
      '/api/mobile/transactions/history',
      query: params,
      parser: (decoded) {
        final list = (decoded as List).cast<Object?>();
        return list
            .map((e) => TransactionSummary.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }

  Future<List<TransactionSummary>> pending({int limit = 20}) async {
    return _api.getJson(
      '/api/mobile/transactions/pending',
      query: {'limit': '$limit'},
      parser: (decoded) {
        final list = (decoded as List).cast<Object?>();
        return list
            .map((e) => TransactionSummary.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }
}
