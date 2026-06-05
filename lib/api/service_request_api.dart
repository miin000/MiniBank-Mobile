import 'authed_api.dart';

class ServiceRequest {
  final int id;
  final String requestType;
  final String title;
  final String? description;
  final String? priorityTag;
  final String status;
  final String submittedAt;
  final String? processedAt;
  final String? processNote;

  ServiceRequest({
    required this.id,
    required this.requestType,
    required this.title,
    this.description,
    this.priorityTag,
    required this.status,
    required this.submittedAt,
    this.processedAt,
    this.processNote,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as int? ?? 0,
      requestType: json['requestType']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      priorityTag: json['priorityTag']?.toString(),
      status: json['status']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? '',
      processedAt: json['processedAt']?.toString(),
      processNote: json['processNote']?.toString(),
    );
  }
}

class LimitChangeRequestResponse {
  final int id;
  final int serviceRequestId;
  final int accountId;
  final String accountNumber;
  final String accountName;
  final String currentDailyTransferLimit;
  final String requestedDailyTransferLimit;
  final String? reason;
  final String status;
  final String submittedAt;
  final String? processedAt;
  final String? processNote;

  LimitChangeRequestResponse({
    required this.id,
    required this.serviceRequestId,
    required this.accountId,
    required this.accountNumber,
    required this.accountName,
    required this.currentDailyTransferLimit,
    required this.requestedDailyTransferLimit,
    required this.reason,
    required this.status,
    required this.submittedAt,
    required this.processedAt,
    required this.processNote,
  });

  factory LimitChangeRequestResponse.fromJson(Map<String, dynamic> json) {
    return LimitChangeRequestResponse(
      id: json['id'] as int? ?? 0,
      serviceRequestId: json['serviceRequestId'] as int? ?? 0,
      accountId: json['accountId'] as int? ?? 0,
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      currentDailyTransferLimit: json['currentDailyTransferLimit']?.toString() ?? '0',
      requestedDailyTransferLimit: json['requestedDailyTransferLimit']?.toString() ?? '0',
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? '',
      submittedAt: json['submittedAt']?.toString() ?? '',
      processedAt: json['processedAt']?.toString(),
      processNote: json['processNote']?.toString(),
    );
  }
}

class ServiceRequestApi {
  final AuthedApi api;

  ServiceRequestApi({required this.api});

  Future<List<ServiceRequest>> getServiceRequests() async {
    final list = await api.getJson<List>(
      '/api/mobile/service-requests',
      parser: (decoded) {
        if (decoded == null) return [];
        if (decoded is! List) return [];
        return decoded;
      },
    );
    return list.map((item) => ServiceRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ServiceRequest> getServiceRequest(int id) async {
    return await api.getJson<ServiceRequest>(
      '/api/mobile/service-requests/$id',
      parser: (decoded) {
        if (decoded == null) throw Exception('Service request not found');
        return ServiceRequest.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<ServiceRequest> createServiceRequest({
    required String requestType,
    required String title,
    String? description,
    String? priorityTag,
    String? payloadJson,
  }) async {
    return await api.postJson<ServiceRequest>(
      '/api/mobile/service-requests',
      body: {
        'requestType': requestType,
        'title': title,
        if (description != null) 'description': description,
        if (priorityTag != null) 'priorityTag': priorityTag,
        if (payloadJson != null) 'payloadJson': payloadJson,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Failed to create service request');
        return ServiceRequest.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<LimitChangeRequestResponse> createLimitChangeRequest({
    required int accountId,
    required String requestedDailyTransferLimit,
    String? reason,
    String? payloadJson,
  }) async {
    return await api.postJson<LimitChangeRequestResponse>(
      '/api/mobile/service-requests/limit-change',
      body: {
        'accountId': accountId,
        'requestedDailyTransferLimit': requestedDailyTransferLimit,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (payloadJson != null) 'payloadJson': payloadJson,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Failed to create limit change request');
        return LimitChangeRequestResponse.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }

  Future<ServiceRequest> createProfileChangeRequest({
    String? fullName,
    String? dob,
    String? address,
    String? reason,
    String? payloadJson,
  }) async {
    return await api.postJson<ServiceRequest>(
      '/api/mobile/service-requests/profile-change',
      body: {
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (address != null && address.isNotEmpty) 'address': address,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (payloadJson != null) 'payloadJson': payloadJson,
      },
      parser: (decoded) {
        if (decoded == null) throw Exception('Failed to create profile change request');
        return ServiceRequest.fromJson(decoded as Map<String, dynamic>);
      },
    );
  }
}
