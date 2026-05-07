import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return dotenv.env['API_BASE_URL'] ?? '';
  }

  static String get cloudinaryCloudName {
    const fromEnv = String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  }

  static String get cloudinaryUploadPreset {
    const fromEnv = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  }
}
