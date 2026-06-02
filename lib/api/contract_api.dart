import 'dart:convert';
import 'authed_api.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

/// Mirrors the `documents` table with owner_type IN ('loan_application','saving')
/// and document_type IN ('loan_contract','saving_certificate').
class ContractItem {
  final int id;
  final String ownerType; // loan_application | saving
  final int ownerId;
  final String documentType; // loan_contract | saving_certificate
  final String? fileName;
  final String? fileUrl;
  final String? mimeType;
  final String verifiedStatus; // pending | approved | rejected
  final String? contractNumber; // pulled from metadata_json or separate field
  final String status; // draft | sent | pending_signature | signed | cancelled
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
    String? contractNumber = json['contractNumber'] as String?;

    if (contractNumber == null && json['metadataJson'] is Map) {
      contractNumber =
          (json['metadataJson'] as Map)['contractNumber'] as String?;
    }

    if (contractNumber == null && json['metadata'] is Map) {
      contractNumber =
          (json['metadata'] as Map)['contractNumber'] as String?;
    }

    return ContractItem(
      id: json['id'] as int,
      ownerType: json['ownerType'] as String? ?? '',
      ownerId: json['ownerId'] as int? ?? 0,
      documentType: json['documentType'] as String? ?? '',
      fileName: json['fileName'] as String?,
      fileUrl: json['fileUrl'] as String?,
      mimeType: json['mimeType'] as String?,
      verifiedStatus: json['verifiedStatus'] as String? ?? 'pending',
      contractNumber: contractNumber,
      status: json['status'] as String? ?? 'draft',
      signedAt: json['signedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  bool get isLoanContract => documentType == 'loan_contract';
  bool get isSavingCertificate => documentType == 'saving_certificate';
  bool get isSigned => status == 'signed';
  bool get isPendingSignature => status == 'pending_signature';
  bool get isSent => status == 'sent';
}

/// Payload for the online signing endpoint.
class SignContractRequest {
  final String digitalSignature;
  final String signedAt;

  const SignContractRequest({
    required this.digitalSignature,
    required this.signedAt,
  });

  Map<String, dynamic> toJson() => {
        'digitalSignature': digitalSignature,
        'signedAt': signedAt,
      };
}

class ContractTemplateSummary {
  final int id;
  final String name;
  final String code;
  final String? description;
  final String? services;
  final String status;
  final String? templateBody;
  final String? templateFileUrl;
  final String? createdAt;
  final String? updatedAt;

  const ContractTemplateSummary({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.services,
    required this.status,
    this.templateBody,
    this.templateFileUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory ContractTemplateSummary.fromJson(Map<String, dynamic> json) {
    return ContractTemplateSummary(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String?,
      services: json['services'] as String?,
      status: json['status'] as String? ?? '',
      templateBody: json['templateBody'] as String?,
      templateFileUrl: json['templateFileUrl'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class ContractOtpSendResponse {
  final bool devMode;
  final String? otp;

  const ContractOtpSendResponse({
    required this.devMode,
    this.otp,
  });

  factory ContractOtpSendResponse.fromJson(Map<String, dynamic> json) {
    return ContractOtpSendResponse(
      devMode: json['devMode'] == true,
      otp: json['otp'] as String?,
    );
  }
}

class ContractAcceptResult {
  final String contractNumber;
  final String status;
  final String? fileUrl;
  final String signedAt;

  const ContractAcceptResult({
    required this.contractNumber,
    required this.status,
    this.fileUrl,
    required this.signedAt,
  });

  factory ContractAcceptResult.fromJson(Map<String, dynamic> json) {
    return ContractAcceptResult(
      contractNumber: json['contractNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      fileUrl: json['fileUrl'] as String?,
      signedAt: json['signedAt']?.toString() ?? '',
    );
  }
}

/// Mirrors backend Contract entity returned by GET/POST /api/mobile/contracts.
class MobileContract {
  final int id;
  final String ownerType; // loan_application | saving
  final int ownerId;
  final String? contractCode;
  final String status; // PENDING | SIGNED
  final String? signedAt;
  final String? createdAt;

  const MobileContract({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    this.contractCode,
    required this.status,
    this.signedAt,
    this.createdAt,
  });

  factory MobileContract.fromJson(Map<String, dynamic> json) {
    return MobileContract(
      id: json['id'] as int,
      ownerType: json['ownerType'] as String? ?? '',
      ownerId: json['ownerId'] as int? ?? 0,
      contractCode: json['contractCode'] as String?,
      status: json['status'] as String? ?? '',
      signedAt: json['signedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }

  bool get isSigned => status.toUpperCase() == 'SIGNED';
  bool get isForLoan => ownerType.toLowerCase() == 'loan_application';
  bool get isForSaving => ownerType.toLowerCase() == 'saving';
}

/// Mirrors backend LoanApplicationResponse.
class LoanApplicationItem {
  final int id;
  final String? productName;
  final double requestedAmount;
  final int requestedTermMonths;
  final String? purpose;
  final String status; // pending | approved | rejected | more_info_needed
  final String? priorityTag;
  final String? submittedAt;

  const LoanApplicationItem({
    required this.id,
    this.productName,
    required this.requestedAmount,
    required this.requestedTermMonths,
    this.purpose,
    required this.status,
    this.priorityTag,
    this.submittedAt,
  });

  factory LoanApplicationItem.fromJson(Map<String, dynamic> json) {
    return LoanApplicationItem(
      id: json['id'] as int,
      productName: json['loanProductName'] as String?,
      requestedAmount: (json['requestedAmount'] as num?)?.toDouble() ?? 0,
      requestedTermMonths: json['requestedTermMonths'] as int? ?? 0,
      purpose: json['purpose'] as String?,
      status: json['status'] as String? ?? 'pending',
      priorityTag: json['priorityTag'] as String?,
      submittedAt: json['submittedAt']?.toString(),
    );
  }
}

// ─── API ─────────────────────────────────────────────────────────────────────

class ContractApi {
  final AuthedApi _api;

  const ContractApi({required AuthedApi api}) : _api = api;

  /// GET /api/contracts/me
  /// Returns all contracts loan + saving for authenticated user.
  Future<List<ContractItem>> getContracts() async {
    final res = await _api.get('/api/contracts/me');
    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    return _list(body)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/contracts/{id}
  Future<ContractItem> getContractById(int id) async {
    final res = await _api.get('/api/contracts/$id');
    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    return ContractItem.fromJson(data);
  }

  /// GET /api/contracts/me?ownerType=loan_application
  Future<List<ContractItem>> getLoanContracts() async {
    final res = await _api.get('/api/contracts/me?ownerType=loan_application');
    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    return _list(body)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/contracts/me?ownerType=saving
  Future<List<ContractItem>> getSavingCertificates() async {
    final res = await _api.get('/api/contracts/me?ownerType=saving');
    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    return _list(body)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/contracts/{id}/sign
  /// Submits user's digital signature to confirm the contract.
  Future<ContractItem> signContract(
    int id, {
    required String digitalSignature,
  }) async {
    final payload = SignContractRequest(
      digitalSignature: digitalSignature,
      signedAt: DateTime.now().toIso8601String(),
    );

    final res = await _api.post(
      '/api/contracts/$id/sign',
      body: jsonEncode(payload.toJson()),
    );

    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    return ContractItem.fromJson(data);
  }

  /// GET /api/mobile/contract-templates/active?code=...
  Future<ContractTemplateSummary> getActiveTemplateByCode(String code) async {
    final encoded = Uri.encodeComponent(code);

    final res = await _api.get(
      '/api/mobile/contract-templates/active?code=$encoded',
    );

    _check(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? body;

    return ContractTemplateSummary.fromJson(data);
  }

  /// POST /api/mobile/contracts/otp/send
  Future<ContractOtpSendResponse> sendContractOtp() async {
    return _api.postJson(
      '/api/mobile/contracts/otp/send',
      body: {},
      parser: (decoded) => ContractOtpSendResponse.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      ),
    );
  }

  /// POST /api/mobile/contracts/accept
  Future<ContractAcceptResult> acceptContract({
    required String referenceType,
    required int referenceId,
    required String templateCode,
    required String otpCode,
    String? signatureData,
  }) async {
    return _api.postJson(
      '/api/mobile/contracts/accept',
      body: {
        'referenceType': referenceType,
        'referenceId': referenceId,
        'templateCode': templateCode,
        'otpCode': otpCode,
        if (signatureData != null) 'signatureData': signatureData,
      },
      parser: (decoded) => ContractAcceptResult.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      ),
    );
  }

  // ─── Mobile contract APIs from new file ───────────────────────────────────

  /// GET /api/mobile/contracts
  /// List contracts loans + savings for current user.
  ///
  /// Đổi tên từ getContracts() của file mới để tránh trùng với getContracts()
  /// đang gọi /api/contracts/me ở file cũ.
  Future<List<MobileContract>> getMobileContracts() async {
    final res = await _api.get('/api/mobile/contracts');
    _check(res);

    final decoded = jsonDecode(res.body);
    final list = _listFromDecoded(decoded);

    return list
        .map((e) => MobileContract.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/mobile/contracts/{id}/sign
  /// Signs the contract and triggers Loan creation for loan_application contracts
  /// or Saving activation for saving contracts.
  ///
  /// Đổi tên từ signContract() của file mới để tránh trùng với signContract()
  /// cũ có truyền digitalSignature.
  Future<MobileContract> signMobileContract(int contractId) async {
    final res = await _api.post(
      '/api/mobile/contracts/$contractId/sign',
      body: '',
    );

    _check(res);

    final decoded = jsonDecode(res.body);
    final map = _mapFromDecoded(decoded);

    return MobileContract.fromJson(map);
  }

  /// GET /api/mobile/loans/applications
  /// Loan applications for current user.
  Future<List<LoanApplicationItem>> getMyLoanApplications() async {
    final res = await _api.get('/api/mobile/loans/applications');
    _check(res);

    final decoded = jsonDecode(res.body);
    final list = _listFromDecoded(decoded);

    return list
        .map(
          (e) => LoanApplicationItem.fromJson(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  List<dynamic> _list(Map<String, dynamic> body) {
    if (body['data'] is List) return body['data'] as List;
    if (body['content'] is List) return body['content'] as List;
    if (body['items'] is List) return body['items'] as List;
    return [];
  }

  List<dynamic> _listFromDecoded(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      final body = decoded.cast<String, dynamic>();
      return _list(body);
    }

    return [];
  }

  Map<String, dynamic> _mapFromDecoded(dynamic decoded) {
    if (decoded is Map) {
      final body = decoded.cast<String, dynamic>();

      if (body['data'] is Map) {
        return (body['data'] as Map).cast<String, dynamic>();
      }

      return body;
    }

    return {};
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