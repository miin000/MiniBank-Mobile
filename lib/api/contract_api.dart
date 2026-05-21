import 'dart:convert';
import 'authed_api.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

/// Mirrors the `documents` table with owner_type IN ('loan_application','saving')
/// and document_type IN ('loan_contract','saving_certificate').
class ContractItem {
  final int    id;
  final String ownerType;          // loan_application | saving
  final int    ownerId;
  final String documentType;       // loan_contract | saving_certificate
  final String? fileName;
  final String? fileUrl;
  final String? mimeType;
  final String verifiedStatus;    // pending | approved | rejected
  final String? contractNumber;   // pulled from metadata_json or separate field
  final String status;            // draft | sent | pending_signature | signed | cancelled
  final String? signedAt;
  final String createdAt;
  final String? note;

  const ContractItem({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.documentType,
    this.fileName,
    this.fileUrl,
    this.mimeType,
    required this.verifiedStatus,
    this.contractNumber,
    required this.status,
    this.signedAt,
    required this.createdAt,
    this.note,
  });

  factory ContractItem.fromJson(Map<String, dynamic> json) {
    // contract_number may live inside metadata_json or as a top-level field
    String? contractNumber = json['contractNumber'] as String?;
    if (contractNumber == null && json['metadataJson'] is Map) {
      contractNumber = (json['metadataJson'] as Map)['contractNumber'] as String?;
    }
    if (contractNumber == null && json['metadata'] is Map) {
      contractNumber = (json['metadata'] as Map)['contractNumber'] as String?;
    }

    return ContractItem(
      id             : json['id'] as int,
      ownerType      : json['ownerType'] as String? ?? '',
      ownerId        : json['ownerId'] as int? ?? 0,
      documentType   : json['documentType'] as String? ?? '',
      fileName       : json['fileName'] as String?,
      fileUrl        : json['fileUrl'] as String?,
      mimeType       : json['mimeType'] as String?,
      verifiedStatus : json['verifiedStatus'] as String? ?? 'pending',
      contractNumber : contractNumber,
      status         : json['status'] as String? ?? 'draft',
      signedAt       : json['signedAt'] as String?,
      createdAt      : json['createdAt'] as String? ?? '',
      note           : json['note'] as String?,
    );
  }

  bool get isLoanContract     => documentType == 'loan_contract';
  bool get isSavingCertificate => documentType == 'saving_certificate';
  bool get isSigned           => status == 'signed';
  bool get isPendingSignature => status == 'pending_signature';
  bool get isSent             => status == 'sent';
}

/// Payload for the online signing endpoint
class SignContractRequest {
  final String digitalSignature;  // base64-encoded RSA signature
  final String signedAt;          // ISO-8601 timestamp

  const SignContractRequest({
    required this.digitalSignature,
    required this.signedAt,
  });

  Map<String, dynamic> toJson() => {
    'digitalSignature': digitalSignature,
    'signedAt'        : signedAt,
  };
}

// ─── API ─────────────────────────────────────────────────────────────────────

class ContractApi {
  final AuthedApi _api;
  const ContractApi({required AuthedApi api}) : _api = api;

  /// GET /api/contracts/me
  /// Returns all contracts (loan + saving) for the authenticated user.
  Future<List<ContractItem>> getContracts() async {
    final res = await _api.get('/api/contracts/me');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _list(body)
        .map((e) => ContractItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/contracts/{id}
  Future<ContractItem> getContractById(int id) async {
    final res = await _api.get('/api/contracts/$id');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ContractItem.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  /// GET /api/contracts/me?ownerType=loan_application
  Future<List<ContractItem>> getLoanContracts() async {
    final res = await _api.get('/api/contracts/me?ownerType=loan_application');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _list(body)
        .map((e) => ContractItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/contracts/me?ownerType=saving
  Future<List<ContractItem>> getSavingCertificates() async {
    final res = await _api.get('/api/contracts/me?ownerType=saving');
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return _list(body)
        .map((e) => ContractItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/contracts/{id}/sign
  /// Submits the user's digital signature to confirm the contract.
  Future<ContractItem> signContract(int id,
      {required String digitalSignature}) async {
    final payload = SignContractRequest(
      digitalSignature: digitalSignature,
      signedAt        : DateTime.now().toIso8601String(),
    );
    final res = await _api.post(
      '/api/contracts/$id/sign',
      body: jsonEncode(payload.toJson()),
    );
    _check(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return ContractItem.fromJson(body['data'] as Map<String, dynamic>? ?? body);
  }

  // ─── helpers ────────────────────────────────────────────────────────────
  List<dynamic> _list(Map<String, dynamic> body) {
    if (body['data'] is List)    return body['data'] as List;
    if (body['content'] is List) return body['content'] as List;
    if (body['items'] is List)   return body['items'] as List;
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
