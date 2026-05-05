import '../auth/auth_storage.dart';
import 'authed_api.dart';

class KycOtpSendResponse {
  final bool devMode;
  final String? otp;

  KycOtpSendResponse({required this.devMode, required this.otp});

  factory KycOtpSendResponse.fromJson(Map<String, dynamic> json) {
    return KycOtpSendResponse(
      devMode: (json['devMode'] as bool?) ?? false,
      otp: json['otp'] as String?,
    );
  }
}

class KycApi {
  final AuthedApi _api;

  KycApi({required String baseUrl, required AuthStorage storage})
      : _api = AuthedApi(baseUrl: baseUrl, storage: storage);

  Future<KycOtpSendResponse> sendOtp() async {
    return _api.postJson(
      '/api/mobile/kyc/otp/send',
      body: {},
      parser: (decoded) => KycOtpSendResponse.fromJson((decoded as Map).cast<String, dynamic>()),
    );
  }

  Future<void> submit({
    required String fullName,
    required String dobIso,
    required String citizenId,
    required String address,
    required String occupation,
    required String monthlyIncome,
    required String citizenFrontImageUrl,
    required String citizenBackImageUrl,
    required String portraitImageUrl,
    required String otpCode,
  }) async {
    await _api.postJson(
      '/api/mobile/kyc/submit',
      body: {
        'fullName': fullName,
        'dob': dobIso,
        'citizenId': citizenId,
        'address': address,
        'occupation': occupation,
        'monthlyIncome': monthlyIncome,
        'citizenFrontImageUrl': citizenFrontImageUrl,
        'citizenBackImageUrl': citizenBackImageUrl,
        'portraitImageUrl': portraitImageUrl,
        'otpCode': otpCode,
      },
      parser: (_) => null,
    );
  }
}
