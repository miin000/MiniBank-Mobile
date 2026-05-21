import '../auth/auth_storage.dart';
import 'authed_api.dart';

class ProfileAccountSummary {
  final int id;
  final String accountNumber;
  final String accountName;
  final String status;

  ProfileAccountSummary({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.status,
  });

  factory ProfileAccountSummary.fromJson(Map<String, dynamic> json) {
    return ProfileAccountSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class ProfileResponse {
  final int id;
  final String? phone;
  final String? email;
  final String? fullName;
  final String? dob;
  final String? address;
  final String? status;
  final String? customerRank;
  final bool hasTransactionPin;
  final bool hasPublicKey;
  final String? deviceId;
  final List<ProfileAccountSummary> accounts;

  ProfileResponse({
    required this.id,
    required this.phone,
    required this.email,
    required this.fullName,
    required this.dob,
    required this.address,
    required this.status,
    required this.customerRank,
    required this.hasTransactionPin,
    required this.hasPublicKey,
    required this.deviceId,
    required this.accounts,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      fullName: json['fullName']?.toString(),
      dob: json['dob']?.toString(),
      address: json['address']?.toString(),
      status: json['status']?.toString(),
      customerRank: json['customerRank']?.toString(),
      hasTransactionPin: (json['hasTransactionPin'] as bool?) ?? false,
      hasPublicKey: (json['hasPublicKey'] as bool?) ?? false,
      deviceId: json['deviceId']?.toString(),
      accounts: ((json['accounts'] as List?) ?? const [])
          .map((e) => ProfileAccountSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}

class ProfileApi {
  final AuthedApi _api;

  ProfileApi({required String baseUrl, required AuthStorage storage})
      : _api = AuthedApi(baseUrl: baseUrl, storage: storage);

  Future<ProfileResponse> me() async {
    return _api.getJson(
      '/api/mobile/profile/me',
      parser: (decoded) => ProfileResponse.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _api.postJson(
      '/api/mobile/profile/change-password',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
      parser: (_) => null,
    );
  }

  Future<ProfileResponse> updateProfile({
    String? fullName,
    DateTime? dob,
    String? address,
  }) async {
    String? dobValue;
    if (dob != null) {
      final year = dob.year.toString().padLeft(4, '0');
      final month = dob.month.toString().padLeft(2, '0');
      final day = dob.day.toString().padLeft(2, '0');
      dobValue = '$year-$month-$day';
    }

    return _api.putJson(
      '/api/mobile/profile/me',
      body: {
        'fullName': fullName,
        'dob': dobValue,
        'address': address,
      },
      parser: (decoded) => ProfileResponse.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<void> uploadDocument({
    required String documentType,
    required String fileUrl,
    String? fileName,
    String? mimeType,
    String? note,
  }) async {
    await _api.postJson(
      '/api/mobile/profile/documents',
      body: {
        'documentType': documentType,
        'fileUrl': fileUrl,
        if (fileName != null) 'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (note != null) 'note': note,
      },
      parser: (_) => null,
    );
  }

  Future<void> setOrChangePin({String? oldPin, required String newPin}) async {
    await _api.postJson(
      '/api/mobile/profile/transaction-pin',
      body: {'oldPin': oldPin, 'newPin': newPin},
      parser: (_) => null,
    );
  }

  Future<void> verifyPin({required String pin}) async {
    await _api.postJson(
      '/api/mobile/auth/pin/verify',
      body: {'pin': pin},
      parser: (_) => null,
    );
  }

  Future<void> setPublicKey({required String publicKeyPem}) async {
    await _api.postJson(
      '/api/mobile/profile/public-key',
      body: {'publicKey': publicKeyPem},
      parser: (_) => null,
    );
  }
}
