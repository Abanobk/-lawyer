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

enum _AuthErrorKind { signup, login }

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SignupResult> signup({
    required String officeName,
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    final uri = ApiConfig.uri('auth/signup');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'office_name': officeName,
        'full_name': fullName.trim(),
        'phone': phone.trim().replaceAll(' ', ''),
        'email': email.trim(),
        'password': password,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SignupResult.fromJson(map);
    }

    throw AuthApiException(
      _parseErrorDetail(res.body, statusCode: res.statusCode, kind: _AuthErrorKind.signup),
      statusCode: res.statusCode,
    );
  }

  Future<({String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final uri = ApiConfig.uri('auth/login');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (
        accessToken: map['access_token'] as String,
        refreshToken: map['refresh_token'] as String,
      );
    }

    throw AuthApiException(
      _parseErrorDetail(res.body, statusCode: res.statusCode, kind: _AuthErrorKind.login),
      statusCode: res.statusCode,
    );
  }

  Future<({String accessToken, String refreshToken})> loginWithGoogle({
    required String idToken,
  }) async {
    final uri = ApiConfig.uri('auth/google');
    final res = await _client.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'},
      body: 'id_token=${Uri.encodeQueryComponent(idToken)}',
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (
        accessToken: map['access_token'] as String,
        refreshToken: map['refresh_token'] as String,
      );
    }

    throw AuthApiException(
      _parseErrorDetail(res.body, statusCode: res.statusCode, kind: _AuthErrorKind.login),
      statusCode: res.statusCode,
    );
  }

  String _parseErrorDetail(String body, {required int? statusCode, required _AuthErrorKind kind}) {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return _fallbackErrorMessage(statusCode, kind);
      final detail = map['detail'];
      if (detail is String) return _mapDetailToAr(detail);
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
      }
      final message = map['message'];
      if (message is String && message.isNotEmpty) return message;
      final error = map['error'];
      if (error is String && error.isNotEmpty) return error;
    } catch (_) {}
    return _fallbackErrorMessage(statusCode, kind);
  }

  String _fallbackErrorMessage(int? statusCode, _AuthErrorKind kind) {
    final action = kind == _AuthErrorKind.signup ? 'إنشاء الحساب' : 'تسجيل الدخول';
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'الخادم غير متاح مؤقتًا (رمز $statusCode). حاول لاحقًا أو تحقق من عمل الخدمة على السيرفر.';
    }
    if (statusCode == 404) {
      return 'مسار الـ API غير موجود (404). تحقق من إعداد النشر وعنوان الواجهة (/api).';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'خطأ من الخادم (رمز $statusCode) أثناء $action. تحقق من السجلات أو اتصل بالدعم.';
    }
    if (statusCode != null && statusCode >= 400) {
      return 'تعذّر $action. رد الخادم غير متوقع (رمز $statusCode). تحقق من البيانات أو الاتصال.';
    }
    return 'تعذّر $action. تحقق من الاتصال أو أن الموقع يصل إلى الخادم (قد يكون الرد ليس JSON).';
  }

  String _mapDetailToAr(String detail) {
    switch (detail) {
      case 'Email already registered':
        return 'هذا البريد مسجّل مسبقًا';
      case 'Invalid credentials':
        return 'بيانات الدخول غير صحيحة';
      default:
        return detail;
    }
  }
}
