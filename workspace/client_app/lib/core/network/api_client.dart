import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Ошибка ответа бэкенда: код статуса плюс `detail` из тела (FastAPI отдаёт
/// ошибки в этом формате — см. `HTTPException(detail=...)` по всему `backend/`).
class ApiException implements Exception {
  ApiException(this.statusCode, this.detail);

  final int statusCode;
  final String detail;

  @override
  String toString() => 'ApiException($statusCode, $detail)';
}

/// Тонкая обёртка над `http.Client`: собирает URL, прокидывает Bearer-токен,
/// разбирает JSON и превращает не-2xx ответы в [ApiException] в одном месте —
/// каждый репозиторий не должен заново парсить `detail` из тела ошибки.
class ApiClient {
  ApiClient({http.Client? client, this.accessToken}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Текущий access-токен курьера. `AuthController` обновляет его после
  /// входа/выхода — здесь нет обращения к хранилищу напрямую, чтобы клиент
  /// оставался синхронным и легко подменяемым в тестах.
  String? accessToken;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConfig.baseUrl}$normalized').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (withAuth && accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool withAuth = true}) async {
    final response = await _client.get(_uri(path, query), headers: _headers(withAuth: withAuth));
    return _decode(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final detail = _extractDetail(body) ?? 'HTTP ${response.statusCode}';
    throw ApiException(response.statusCode, detail);
  }

  String? _extractDetail(dynamic body) {
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) return detail;
      return jsonEncode(detail);
    }
    return null;
  }

  void close() => _client.close();
}
