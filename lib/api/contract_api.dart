import 'dart:convert';
import 'authed_api.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

/// Legacy contract/document model used by /api/contracts/me.
class ContractItem {
  final int id;
  final String ownerType;
  final int ownerId;
  final String documentType;
  final String? fileName;
  final String? fileUrl;
  final String? mimeType;
  final String verifiedStatus;
  final String? contractNumber;
  final String status;
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
      contractNumber = (json['metadataJson'] as Map)['contractNumber'] as String?;
    }

    if (contractNumber == null && json['metadata'] is Map) {
      contractNumber = (json['metadata'] as Map)['contractNumber'] as String?;
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
      signedAt: json['signedAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      note: json['note'] as String?,
    );
  }

  bool get isLoanContract => documentType == 'loan_contract' || ownerType == 'loan_application';
  bool get isSavingCertificate => documentType == 'saving_certificate' || ownerType == 'saving';
  bool get isSigned => status.toLowerCase() == 'signed';
  bool get isPendingSignature => status.toLowerCase() == 'pending_signature';
  bool get isSent => status.toLowerCase() == 'sent';
}

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
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
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

/// Mirrors backend MobileContractResponse returned by /api/mobile/contracts.
class MobileContract {
  final int id;
  final String ownerType; // loan_application | saving
  final int ownerId;
  final String? contractNumber;
  final String status; // pending_signature | signed | cancelled ...
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
      contractNumber: json['contractNumber'] as String? ?? json['contractCode'] as String?,
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
    return s == 'pending_signature' || s == 'pending' || s == 'sent' || s == 'draft';
  }

  bool get isForLoan => ownerType.toLowerCase() == 'loan_application';
  bool get isForSaving => ownerType.toLowerCase() == 'saving';
}

class LoanApplicationItem {
  final int id;
  final String? productName;
  final double requestedAmount;
  final int requestedTermMonths;
  final String? purpose;
  final String status;
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

  /// Legacy endpoint: GET /api/contracts/me
  Future<List<ContractItem>> getContracts() async {
    final res = await _api.get('/api/contracts/me');
    _check(res);

    final decoded = jsonDecode(res.body);
    return _listFromDecoded(decoded)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Legacy endpoint: GET /api/contracts/{id}
  Future<ContractItem> getContractById(int id) async {
    final res = await _api.get('/api/contracts/$id');
    _check(res);

    return ContractItem.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  Future<List<ContractItem>> getLoanContracts() async {
    final res = await _api.get('/api/contracts/me?ownerType=loan_application');
    _check(res);

    final decoded = jsonDecode(res.body);
    return _listFromDecoded(decoded)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ContractItem>> getSavingCertificates() async {
    final res = await _api.get('/api/contracts/me?ownerType=saving');
    _check(res);

    final decoded = jsonDecode(res.body);
    return _listFromDecoded(decoded)
        .map((e) => ContractItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Legacy endpoint: POST /api/contracts/{id}/sign
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
    return ContractItem.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  Future<ContractTemplateSummary> getActiveTemplateByCode(String code) async {
    final encoded = Uri.encodeComponent(code);

    final res = await _api.get(
      '/api/mobile/contract-templates/active?code=$encoded',
    );

    _check(res);
    return ContractTemplateSummary.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  Future<ContractOtpSendResponse> sendContractOtp() async {
    return _api.postJson(
      '/api/mobile/contracts/otp/send',
      body: {},
      parser: (decoded) => ContractOtpSendResponse.fromJson(
        (decoded as Map).cast<String, dynamic>(),
      ),
    );
  }

  /// Legacy/self-service accept endpoint. Không dùng cho flow vay cần admin duyệt.
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

  /// GET /api/mobile/contracts
  Future<List<MobileContract>> getMobileContracts() async {
    final res = await _api.get('/api/mobile/contracts');
    _check(res);

    final decoded = jsonDecode(res.body);
    return _listFromDecoded(decoded)
        .map((e) => MobileContract.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/mobile/contracts/{id}
  Future<MobileContract> getMobileContractDetail(int id) async {
    final res = await _api.get('/api/mobile/contracts/$id');
    _check(res);

    return MobileContract.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  /// POST /api/mobile/contracts/{id}/sign
  Future<MobileContract> signMobileContract(int id) async {
    final res = await _api.post('/api/mobile/contracts/$id/sign');
    _check(res);

    return MobileContract.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  Future<MobileContract> signMobileContractWithOtp(int id, String otpCode) async {
    final res = await _api.post(
      '/api/mobile/contracts/$id/sign',
      body: jsonEncode({'otpCode': otpCode}),
    );
    _check(res);
    return MobileContract.fromJson(_mapFromDecoded(jsonDecode(res.body)));
  }

  Future<List<LoanApplicationItem>> getMyLoanApplications() async {
    final res = await _api.get('/api/mobile/loans/applications');
    _check(res);

    final decoded = jsonDecode(res.body);
    return _listFromDecoded(decoded)
        .map((e) => LoanApplicationItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<dynamic> _listFromDecoded(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      final body = decoded.cast<String, dynamic>();
      if (body['data'] is List) return body['data'] as List;
      if (body['content'] is List) return body['content'] as List;
      if (body['items'] is List) return body['items'] as List;
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
