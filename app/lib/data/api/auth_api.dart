import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';

class SignupResult {
  SignupResult({
    required this.officeCode,
    required this.officeLink,
    required this.trialEndAt,
    required this.accessToken,
    required this.refreshToken,
  });

  final String officeCode;
  final String officeLink;
  final DateTime trialEndAt;
  final String accessToken;
  final String refreshToken;

  factory SignupResult.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as Map<String, dynamic>;
    return SignupResult(
      officeCode: json['office_code'] as String,
      officeLink: json['office_link'] as String,
      trialEndAt: DateTime.parse(json['trial_end_at'] as String),
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SignupResult> signup({
    required String officeName,
    required String email,
    required String password,
  }) async {
    final uri = ApiConfig.uri('auth/signup');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'office_name': officeName,
        'email': email.trim(),
        'password': password,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SignupResult.fromJson(map);
    }

    throw AuthApiException(_parseErrorDetail(res.body), statusCode: res.statusCode);
  }

  String _parseErrorDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return 'فشل الطلب';
      final detail = map['detail'];
      if (detail is String) return _mapDetailToAr(detail);
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
    } catch (_) {}
    return 'تعذّر إنشاء الحساب. تحقق من الاتصال أو البيانات.';
  }

  String _mapDetailToAr(String detail) {
    switch (detail) {
      case 'Email already registered':
        return 'هذا البريد مسجّل مسبقًا';
      default:
        return detail;
    }
  }
}
