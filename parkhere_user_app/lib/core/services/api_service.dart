import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class ApiUnauthorizedException implements Exception {
  const ApiUnauthorizedException();

  @override
  String toString() => 'Sessao expirada. Entre novamente.';
}

class ApiConnectionException implements Exception {
  const ApiConnectionException();

  @override
  String toString() => 'Nao foi possivel conectar com a API.';
}

class ApiService {
  static Future<void> Function()? onUnauthorized;
  static const _timeout = Duration(seconds: 12);

  Future<List<dynamic>> get(String endpoint) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http.get(url).timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }

    throw Exception(_errorMessage(response));
  }

  Future<List<dynamic>> getAuthorized(String endpoint, String token) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http
        .get(url, headers: _authorizedHeaders(token))
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception(_errorMessage(response));
  }

  Future<Map<String, dynamic>> getAuthorizedMap(
    String endpoint,
    String token,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http
        .get(url, headers: _authorizedHeaders(token))
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception(_errorMessage(response));
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    late final http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on http.ClientException {
      throw const ApiConnectionException();
    } on TimeoutException {
      throw const ApiConnectionException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception(_errorMessage(response));
  }

  Future<Map<String, dynamic>> postAuthorized(
    String endpoint,
    Map<String, dynamic> body,
    String token,
  ) async {
    final url = Uri.parse("${ApiConstants.baseUrl}$endpoint");

    final response = await http
        .post(url, headers: _authorizedHeaders(token), body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    await _handleUnauthorized(response);
    throw Exception(_errorMessage(response));
  }

  Future<Map<String, dynamic>> uploadAuthorizedFile(
    String endpoint,
    String token,
    String fileName,
    List<int> bytes,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
    )..headers.addAll(_authorizedHeaders(token));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: _imageMediaType(fileName),
      ),
    );
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    await _handleUnauthorized(response);
    throw Exception(_errorMessage(response));
  }

  http.MediaType _imageMediaType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => http.MediaType('image', 'png'),
      'webp' => http.MediaType('image', 'webp'),
      'heic' => http.MediaType('image', 'heic'),
      'heif' => http.MediaType('image', 'heif'),
      _ => http.MediaType('image', 'jpeg'),
    };
  }

  String _errorMessage(http.Response response) {
    try {
      final detail =
          (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
      if (detail is String) {
        return const {
              'Pre-reservation expired':
                  'A pré-reserva expirou. Crie uma nova reserva.',
              'Spot already reserved':
                  'Esta vaga acabou de ser reservada. Escolha outra.',
              'Cash received must cover the total':
                  'O valor recebido deve cobrir o total.',
              'Arrival must not be in the past':
                  'A previsão de chegada não pode estar no passado.',
            }[detail] ??
            detail;
      }
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
    } catch (_) {
      // Non-JSON responses keep the HTTP status without exposing the raw body.
    }
    return 'Erro na API: ${response.statusCode}';
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

    final response = await http
        .put(url, headers: _authorizedHeaders(token), body: jsonEncode(body))
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_errorMessage(response));
  }

  Map<String, String> _authorizedHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
