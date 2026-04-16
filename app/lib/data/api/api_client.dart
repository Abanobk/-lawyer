import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthTokenStorage? tokenStorage,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _http;
  final AuthTokenStorage _tokens;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokens.getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json; charset=utf-8'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    T Function(Object? json)? decode,
  }) async {
    var uri = ApiConfig.uri(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final res = await _http.get(uri, headers: await _authHeaders());
    return _handleJson(res, decode: decode);
  }

  Future<T> postJson<T>(
    String path,
    Object body, {
    T Function(Object? json)? decode,
  }) async {
    final uri = ApiConfig.uri(path);
    final res = await _http.post(uri, headers: await _authHeaders(), body: jsonEncode(body));
    return _handleJson(res, decode: decode);
  }

  Future<T> putJson<T>(
    String path,
    Object body, {
    T Function(Object? json)? decode,
  }) async {
    final uri = ApiConfig.uri(path);
    final res = await _http.put(uri, headers: await _authHeaders(), body: jsonEncode(body));
    return _handleJson(res, decode: decode);
  }

  Future<T> deleteJson<T>(
    String path, {
    T Function(Object? json)? decode,
  }) async {
    final uri = ApiConfig.uri(path);
    final res = await _http.delete(uri, headers: await _authHeaders());
    return _handleJson(res, decode: decode);
  }

  T _handleJson<T>(http.Response res, {T Function(Object? json)? decode}) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    final text = utf8.decode(res.bodyBytes);

    if (!ok) {
      throw ApiException(_parseErrorDetail(text), statusCode: res.statusCode);
    }

    if (decode == null) {
      return jsonDecode(text) as T;
    }
    return decode(jsonDecode(text));
  }

  String _parseErrorDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return 'فشل الطلب';
      final detail = map['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    } catch (_) {}
    return 'حدث خطأ غير متوقع';
  }
}

