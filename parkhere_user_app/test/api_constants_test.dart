import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkhere_user_app/core/constants/api_constants.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    dotenv.clean();
  });

  test('missing env uses Android fallback without throwing', () {
    dotenv.clean();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ApiConstants.baseUrl, 'http://10.0.2.2:8000');
  });

  test('configured network address is preserved for physical devices', () {
    dotenv.testLoad(fileInput: 'API_URL=http://192.168.1.20:8000');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ApiConstants.baseUrl, 'http://192.168.1.20:8000');
  });
}
