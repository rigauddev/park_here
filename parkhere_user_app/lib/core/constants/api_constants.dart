import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl {
    const defineUrl = String.fromEnvironment('API_URL');
    if (defineUrl.isNotEmpty) return defineUrl;

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != '0.0.0.0') {
        return 'http://$host:8000';
      }
      return 'http://localhost:8000';
    }

    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      if (defaultTargetPlatform == TargetPlatform.android &&
          _isLoopbackUrl(envUrl)) {
        return 'http://10.0.2.2:8000';
      }
      return envUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  static bool _isLoopbackUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.host == '127.0.0.1' || uri.host == 'localhost');
  }
}
