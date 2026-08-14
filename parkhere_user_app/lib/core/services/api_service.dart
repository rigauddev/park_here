import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class ApiUnauthorizedException implements Exception {
  const ApiUnauthorizedException();

  @override
  String toString() => 'Sessao expirada. Entre novamente.';
}

class ApiService {
  static Future<void> Function()? onUnauthorized;

  Future<List<dynamic>> get(String endpoint) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }

    throw Exception("Erro na API: ${response.statusCode}");
  }

  Future<List<dynamic>> getAuthorized(String endpoint, String token) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.get(url, headers: _authorizedHeaders(token));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception("Erro na API: ${response.statusCode}");
  }

  Future<Map<String, dynamic>> getAuthorizedMap(
    String endpoint,
    String token,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.get(url, headers: _authorizedHeaders(token));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception("Erro na API: ${response.statusCode}");
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception("Erro na API: ${response.statusCode}");
  }

  Future<Map<String, dynamic>> postAuthorized(
    String endpoint,
    Map<String, dynamic> body,
    String token,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.post(
      url,
      headers: _authorizedHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception("Erro na API: ${response.statusCode}");
  }

  Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode != 401) return;
    await onUnauthorized?.call();
    throw const ApiUnauthorizedException();
  }

  Future<Map<String, dynamic>> putAuthorized(
    String endpoint,
    Map<String, dynamic> body,
    String token,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.put(
      url,
      headers: _authorizedHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Erro na API: ${response.statusCode}");
  }

  Map<String, String> _authorizedHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
