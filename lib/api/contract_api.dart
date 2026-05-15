import 'authed_api.dart';

class ContractItem {
  final int id;
  final String ownerType;
  final int ownerId;
  final String? contractNumber;
  final String? fileUrl;
  final String? status;
  final String? signedAt;
  final String? createdAt;

  ContractItem({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    this.contractNumber,
    this.fileUrl,
    this.status,
    this.signedAt,
    this.createdAt,
  });

  factory ContractItem.fromJson(Map<String, dynamic> json) {
    return ContractItem(
      id: json['id'] as int? ?? 0,
      ownerType: json['ownerType']?.toString() ?? '',
      ownerId: json['ownerId'] as int? ?? 0,
      contractNumber: json['contractNumber']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      status: json['status']?.toString(),
      signedAt: json['signedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class ContractApi {
  final AuthedApi api;

  ContractApi({required this.api});

  Future<List<ContractItem>> getContracts() async {
    final list = await api.getJson<List>(
      '/api/mobile/contracts',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list
        .map((item) => ContractItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
