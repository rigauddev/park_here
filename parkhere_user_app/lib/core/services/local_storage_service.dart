import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _accessKey = "access_token";
  static const _refreshKey = "refresh_token";
  static const _accountTypeKey = "account_type";
  static const _emailKey = "user_email";

  Future<void> saveTokens(
    String access,
    String refresh, {
    String? accountType,
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
    if (accountType != null) {
      await prefs.setString(_accountTypeKey, accountType);
    }
    if (userEmail != null) {
      await prefs.setString(_emailKey, userEmail);
    }
  }

  Future<Map<String, String?>> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "access": prefs.getString(_accessKey),
      "refresh": prefs.getString(_refreshKey),
      "account_type": prefs.getString(_accountTypeKey),
      "user_email": prefs.getString(_emailKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
