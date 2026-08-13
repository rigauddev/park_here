import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _accessKey = "access_token";
  static const _refreshKey = "refresh_token";

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<Map<String, String?>> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "access": prefs.getString(_accessKey),
      "refresh": prefs.getString(_refreshKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}