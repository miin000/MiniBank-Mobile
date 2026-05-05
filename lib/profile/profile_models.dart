class ProfileAccount {
  final int id;
  final String accountNumber;
  final String accountName;
  final String status;

  ProfileAccount({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.status,
  });

  factory ProfileAccount.fromJson(Map<String, dynamic> json) {
    return ProfileAccount(
      id: (json['id'] as num).toInt(),
      accountNumber: (json['accountNumber'] as String?) ?? '',
      accountName: (json['accountName'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
    );
  }
}

class ProfileResponse {
  final int id;
  final String phone;
  final String email;
  final String? fullName;
  final DateTime? dob;
  final String? address;
  final String? status;
  final String? customerRank;
  final bool hasTransactionPin;
  final bool hasPublicKey;
  final String? deviceId;
  final List<ProfileAccount> accounts;

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
    final accountsJson = (json['accounts'] as List<dynamic>?) ?? const [];
    return ProfileResponse(
      id: (json['id'] as num).toInt(),
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      fullName: json['fullName'] as String?,
      dob: DateTime.tryParse((json['dob'] as String?) ?? ''),
      address: json['address'] as String?,
      status: json['status'] as String?,
      customerRank: json['customerRank'] as String?,
      hasTransactionPin: (json['hasTransactionPin'] as bool?) ?? false,
      hasPublicKey: (json['hasPublicKey'] as bool?) ?? false,
      deviceId: json['deviceId'] as String?,
      accounts: accountsJson
          .map((e) => ProfileAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
