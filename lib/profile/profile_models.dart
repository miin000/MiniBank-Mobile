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
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
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
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      dob: DateTime.tryParse(json['dob']?.toString() ?? ''),
      address: json['address']?.toString(),
      status: json['status']?.toString(),
      customerRank: json['customerRank']?.toString(),
      hasTransactionPin: (json['hasTransactionPin'] as bool?) ?? false,
      hasPublicKey: (json['hasPublicKey'] as bool?) ?? false,
      deviceId: json['deviceId']?.toString(),
      accounts: accountsJson
          .map((e) => ProfileAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
