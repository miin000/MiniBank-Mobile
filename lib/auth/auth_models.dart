class AuthResponse {
  final String tokenType;
  final String accessToken;
  final int expiresInSeconds;
  final AuthUser user;

  AuthResponse({
    required this.tokenType,
    required this.accessToken,
    required this.expiresInSeconds,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      tokenType: json['tokenType'] as String,
      accessToken: json['accessToken'] as String,
      expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthOtpSendResponse {
  final bool devMode;
  final String? otp;

  AuthOtpSendResponse({required this.devMode, required this.otp});

  factory AuthOtpSendResponse.fromJson(Map<String, dynamic> json) {
    return AuthOtpSendResponse(
      devMode: (json['devMode'] as bool?) ?? false,
      otp: json['otp'] as String?,
    );
  }
}

class AuthUser {
  final int id;
  final String type;
  final String? username;
  final String? phone;
  final List<String> roles;

  AuthUser({
    required this.id,
    required this.type,
    required this.username,
    required this.phone,
    required this.roles,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rolesJson = (json['roles'] as List<dynamic>?) ?? const [];
    return AuthUser(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      roles: rolesJson.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'username': username,
      'phone': phone,
      'roles': roles,
    };
  }
}
