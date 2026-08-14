import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    const defineUrl = String.fromEnvironment('API_URL');
    if (defineUrl.isNotEmpty) return defineUrl;

    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }
}
