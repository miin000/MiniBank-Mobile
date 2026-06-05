class MobileContract {
  final int id;
  final String ownerType; // loan_application | saving
  final int ownerId;
  final String? contractNumber;
  final String status; // PENDING_SIGNATURE | SIGNED | pending_signature | signed
  final String? signedAt;
  final String? createdAt;
  final String? fileUrl;
  final String? renderedBody;

  const MobileContract({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    this.contractNumber,
    required this.status,
    this.signedAt,
    this.createdAt,
    this.fileUrl,
    this.renderedBody,
  });

  factory MobileContract.fromJson(Map<String, dynamic> json) {
    return MobileContract(
      id: json['id'] as int,
      ownerType: json['ownerType'] as String? ?? '',
      ownerId: json['ownerId'] as int? ?? 0,
      contractNumber: json['contractNumber'] as String?,
      status: json['status'] as String? ?? '',
      signedAt: json['signedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      fileUrl: json['fileUrl'] as String?,
      renderedBody: json['renderedBody'] as String?,
    );
  }

  bool get isSigned => status.toLowerCase() == 'signed';

  bool get isPendingSignature {
    final s = status.toLowerCase();
    return s == 'pending_signature' || s == 'pending' || s == 'sent';
  }

  bool get isForLoan => ownerType.toLowerCase() == 'loan_application';
  bool get isForSaving => ownerType.toLowerCase() == 'saving';
}