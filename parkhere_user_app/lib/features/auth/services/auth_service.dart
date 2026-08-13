import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = "auth_token";
  static const _expiryKey = "auth_expiry";

  Future<void> saveToken(String token, DateTime expiry) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _expiryKey, value: expiry.toIso8601String());
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<bool> isTokenValid() async {
    final expiryStr = await _storage.read(key: _expiryKey);
    if (expiryStr == null) return false;

    final expiry = DateTime.parse(expiryStr);
    return DateTime.now().isBefore(expiry);
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}