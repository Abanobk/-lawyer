import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class PlanDto {
  PlanDto({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.durationDays,
    this.instapayLink,
    this.promoImagePath,
    this.packageKey,
    this.packageName,
    this.maxUsers,
    this.allowedPermKeys,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int priceCents;
  final int durationDays;
  final String? instapayLink;
  final String? promoImagePath;
  final String? packageKey;
  final String? packageName;
  final int? maxUsers;
  final List<String>? allowedPermKeys;
  final bool isActive;
  final DateTime createdAt;

  factory PlanDto.fromJson(Map<String, dynamic> json) {
    return PlanDto(
      id: json['id'] as int,
      name: json['name'] as String,
      priceCents: json['price_cents'] as int,
      durationDays: json['duration_days'] as int,
      instapayLink: json['instapay_link'] as String?,
      promoImagePath: json['promo_image_path'] as String?,
      packageKey: json['package_key'] as String?,
      packageName: json['package_name'] as String?,
      maxUsers: (json['max_users'] as int?),
      allowedPermKeys: (json['allowed_perm_keys'] as List?)?.cast<String>(),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PlansApi {
  PlansApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<PlanDto>> list() async {
    return _client.getJson<List<PlanDto>>(
      'plans',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PlanDto.fromJson).toList();
      },
    );
  }
}

class PlanPromoFilesApiException implements Exception {
  PlanPromoFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class PlanPromoFilesApi {
  PlanPromoFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<(Uint8List bytes, String? contentType)> downloadPromo(int planId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw PlanPromoFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('plans/$planId/promo-image');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PlanPromoFilesApiException('فشل تنزيل صورة الباقة', statusCode: res.statusCode);
    }
    return (res.bodyBytes, res.headers['content-type']);
  }
}

