import '../auth/auth_storage.dart';
import 'authed_api.dart';

class AccountResolve {
  final String accountNumber;
  final String accountName;

  AccountResolve({required this.accountNumber, required this.accountName});

  factory AccountResolve.fromJson(Map<String, dynamic> json) {
    return AccountResolve(
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
    );
  }
}

class AccountQr {
  final String accountNumber;
  final String accountName;
  final String payload;

  AccountQr({required this.accountNumber, required this.accountName, required this.payload});

  factory AccountQr.fromJson(Map<String, dynamic> json) {
    return AccountQr(
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      payload: json['payload']?.toString() ?? '',
    );
  }
}

class AccountSummary {
  final String accountNumber;
  final String accountName;
  final String availableBalance;
  final String currentBalance;
  final String status;
  final String? customerRank;

  AccountSummary({
    required this.accountNumber,
    required this.accountName,
    required this.availableBalance,
    required this.currentBalance,
    required this.status,
    required this.customerRank,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      availableBalance: json['availableBalance']?.toString() ?? '0',
      currentBalance: json['currentBalance']?.toString() ?? '0',
      status: json['status']?.toString() ?? '',
      customerRank: json['customerRank']?.toString(),
    );
  }
}

class AccountSuggestions {
  final String desired;
  final List<String> suggestions;

  AccountSuggestions({required this.desired, required this.suggestions});

  factory AccountSuggestions.fromJson(Map<String, dynamic> json) {
    return AccountSuggestions(
      desired: json['desired']?.toString() ?? '',
      suggestions: ((json['suggestions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class AccountApi {
  final AuthedApi _api;

  AccountApi({required String baseUrl, required AuthStorage storage})
      : _api = AuthedApi(baseUrl: baseUrl, storage: storage);

  Future<List<AccountResolve>> myAccounts() async {
    return _api.getJson(
      '/api/mobile/accounts/me',
      parser: (decoded) {
        final list = (decoded as List).cast<Object?>();
        return list
            .map((e) => AccountResolve.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false);
      },
    );
  }

  Future<AccountResolve> resolveAccount(String accountNumber) async {
    return _api.getJson(
      '/api/mobile/accounts/resolve',
      query: {'accountNumber': accountNumber},
      parser: (decoded) => AccountResolve.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<AccountQr> myQr({String? accountNumber}) async {
    final query = <String, String>{};
    if (accountNumber != null && accountNumber.trim().isNotEmpty) {
      query['accountNumber'] = accountNumber.trim();
    }
    return _api.getJson(
      '/api/mobile/accounts/me/qr',
      query: query,
      parser: (decoded) => AccountQr.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<AccountSuggestions> suggestions({required String desired, int? limit}) async {
    final q = <String, String>{'desired': desired};
    if (limit != null) q['limit'] = '$limit';
    return _api.getJson(
      '/api/mobile/accounts/suggestions',
      query: q,
      parser: (decoded) => AccountSuggestions.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<AccountResolve> createMyAccount({required String accountNumber}) async {
    return _api.postJson(
      '/api/mobile/accounts/me/create',
      body: {'accountNumber': accountNumber},
      parser: (decoded) => AccountResolve.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<AccountSummary> summary() async {
    return _api.getJson(
      '/api/mobile/accounts/summary',
      parser: (decoded) => AccountSummary.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }
}
