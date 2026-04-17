import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';

class AdminOfficeDto {
  AdminOfficeDto({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String code;
  final String name;
  final String status;
  final DateTime createdAt;

  factory AdminOfficeDto.fromJson(Map<String, dynamic> json) {
    return AdminOfficeDto(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminSubscriptionDto {
  AdminSubscriptionDto({
    required this.id,
    required this.officeId,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.planNameSnapshot,
    this.priceSnapshotCents,
    this.notes,
    required this.maxUsersEffective,
    this.maxUsersOverride,
  });

  final int id;
  final int officeId;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String? planNameSnapshot;
  final int? priceSnapshotCents;
  final String? notes;
  final int maxUsersEffective;
  final int? maxUsersOverride;

  factory AdminSubscriptionDto.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionDto(
      id: json['id'] as int,
      officeId: json['office_id'] as int,
      status: json['status'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      planNameSnapshot: json['plan_name_snapshot'] as String?,
      priceSnapshotCents: json['price_snapshot_cents'] as int?,
      notes: json['notes'] as String?,
      maxUsersEffective: (json['max_users_effective'] as num?)?.toInt() ?? 3,
      maxUsersOverride: (json['max_users_override'] as num?)?.toInt(),
    );
  }
}

class AdminTrialOfficeUsersDto {
  AdminTrialOfficeUsersDto({
    required this.officeId,
    required this.officeName,
    required this.trialStartAt,
    required this.trialEndAt,
    required this.activeUsersCount,
    required this.activeDaysCount,
  });

  final int officeId;
  final String officeName;
  final DateTime trialStartAt;
  final DateTime trialEndAt;
  final int activeUsersCount;
  final int activeDaysCount;

  factory AdminTrialOfficeUsersDto.fromJson(Map<String, dynamic> json) {
    return AdminTrialOfficeUsersDto(
      officeId: json['office_id'] as int,
      officeName: json['office_name'] as String,
      trialStartAt: DateTime.parse(json['trial_start_at'] as String),
      trialEndAt: DateTime.parse(json['trial_end_at'] as String),
      activeUsersCount: json['active_users_count'] as int,
      activeDaysCount: (json['active_days_count'] as int?) ?? 0,
    );
  }
}

class AdminTrialAnalyticsDto {
  AdminTrialAnalyticsDto({
    required this.days,
    required this.totalTrialOffices,
    required this.offices,
  });

  final int days;
  final int totalTrialOffices;
  final List<AdminTrialOfficeUsersDto> offices;

  factory AdminTrialAnalyticsDto.fromJson(Map<String, dynamic> json) {
    return AdminTrialAnalyticsDto(
      days: json['days'] as int,
      totalTrialOffices: json['total_trial_offices'] as int,
      offices: (json['offices'] as List).cast<Map<String, dynamic>>().map(AdminTrialOfficeUsersDto.fromJson).toList(),
    );
  }
}

class AdminActivePlanSummaryDto {
  AdminActivePlanSummaryDto({
    required this.planName,
    required this.officeCount,
    required this.avgRemainingDays,
    this.planId,
    this.planPackageKey,
  });

  final int? planId;
  final String planName;
  final String? planPackageKey;
  final int officeCount;
  final int avgRemainingDays;

  factory AdminActivePlanSummaryDto.fromJson(Map<String, dynamic> json) {
    return AdminActivePlanSummaryDto(
      planId: json['plan_id'] as int?,
      planName: json['plan_name'] as String,
      planPackageKey: json['plan_package_key'] as String?,
      officeCount: json['office_count'] as int,
      avgRemainingDays: json['avg_remaining_days'] as int,
    );
  }
}

class AdminSubscriptionsAnalyticsDto {
  AdminSubscriptionsAnalyticsDto({
    required this.days,
    required this.totalActiveOffices,
    required this.byPlan,
  });

  final int days;
  final int totalActiveOffices;
  final List<AdminActivePlanSummaryDto> byPlan;

  factory AdminSubscriptionsAnalyticsDto.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionsAnalyticsDto(
      days: json['days'] as int,
      totalActiveOffices: json['total_active_offices'] as int,
      byPlan: (json['by_plan'] as List).cast<Map<String, dynamic>>().map(AdminActivePlanSummaryDto.fromJson).toList(),
    );
  }
}

class AdminSubscriptionsSeriesPointDto {
  AdminSubscriptionsSeriesPointDto({
    required this.day,
    required this.activeOffices,
    required this.pctOfMax,
  });

  final DateTime day;
  final int activeOffices;
  final int pctOfMax;

  factory AdminSubscriptionsSeriesPointDto.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionsSeriesPointDto(
      day: DateTime.parse(json['day'] as String),
      activeOffices: json['active_offices'] as int,
      pctOfMax: json['pct_of_max'] as int,
    );
  }
}

class AdminSubscriptionsSeriesDto {
  AdminSubscriptionsSeriesDto({required this.days, required this.points});

  final int days;
  final List<AdminSubscriptionsSeriesPointDto> points;

  factory AdminSubscriptionsSeriesDto.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionsSeriesDto(
      days: json['days'] as int,
      points: (json['points'] as List).cast<Map<String, dynamic>>().map(AdminSubscriptionsSeriesPointDto.fromJson).toList(),
    );
  }
}

class AdminAlertsDto {
  AdminAlertsDto({
    required this.trialExpiring3d,
    required this.activeExpiring7d,
    required this.expiredOrInactive,
  });

  final int trialExpiring3d;
  final int activeExpiring7d;
  final int expiredOrInactive;

  factory AdminAlertsDto.fromJson(Map<String, dynamic> json) {
    return AdminAlertsDto(
      trialExpiring3d: json['trial_expiring_3d'] as int,
      activeExpiring7d: json['active_expiring_7d'] as int,
      expiredOrInactive: json['expired_or_inactive'] as int,
    );
  }
}

class AdminSuperAdminDto {
  AdminSuperAdminDto({
    required this.id,
    required this.email,
    required this.isActive,
    required this.createdAt,
    this.fullName,
  });

  final int id;
  final String email;
  final bool isActive;
  final DateTime createdAt;
  final String? fullName;

  factory AdminSuperAdminDto.fromJson(Map<String, dynamic> json) {
    return AdminSuperAdminDto(
      id: json['id'] as int,
      email: json['email'] as String,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      fullName: json['full_name'] as String?,
    );
  }
}

class AdminPlanDto {
  AdminPlanDto({
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

  factory AdminPlanDto.fromJson(Map<String, dynamic> json) {
    return AdminPlanDto(
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

class AdminPaymentProofDto {
  AdminPaymentProofDto({
    required this.id,
    required this.officeId,
    required this.imagePath,
    required this.status,
    required this.uploadedAt,
    this.planId,
    this.notes,
    this.amountSnapshotCents,
    this.instapayLinkSnapshot,
    this.referenceCode,
    this.reviewedByUserId,
    this.reviewedAt,
    this.decisionNotes,
  });

  final int id;
  final int officeId;
  final String imagePath;
  final String status;
  final int? planId;
  final String? notes;
  final int? amountSnapshotCents;
  final String? instapayLinkSnapshot;
  final String? referenceCode;
  final int? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? decisionNotes;
  final DateTime uploadedAt;

  factory AdminPaymentProofDto.fromJson(Map<String, dynamic> json) {
    return AdminPaymentProofDto(
      id: json['id'] as int,
      officeId: json['office_id'] as int,
      imagePath: json['image_path'] as String,
      planId: json['plan_id'] as int?,
      status: (json['status'] as String?) ?? 'pending',
      notes: json['notes'] as String?,
      amountSnapshotCents: json['amount_snapshot_cents'] as int?,
      instapayLinkSnapshot: json['instapay_link_snapshot'] as String?,
      referenceCode: json['reference_code'] as String?,
      reviewedByUserId: json['reviewed_by_user_id'] as int?,
      reviewedAt: json['reviewed_at'] == null ? null : DateTime.parse(json['reviewed_at'] as String),
      decisionNotes: json['decision_notes'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class AdminApi {
  AdminApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<AdminOfficeDto>> listOffices() async {
    return _client.getJson<List<AdminOfficeDto>>(
      'admin/offices',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(AdminOfficeDto.fromJson).toList();
      },
    );
  }

  Future<AdminSubscriptionDto> getSubscription(int officeId) async {
    return _client.getJson<AdminSubscriptionDto>(
      'admin/offices/$officeId/subscription',
      decode: (json) => AdminSubscriptionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminSubscriptionDto> patchOfficeSubscription(int officeId, Map<String, dynamic> body) async {
    return _client.patchJson<AdminSubscriptionDto>(
      'admin/offices/$officeId/subscription',
      body,
      decode: (json) => AdminSubscriptionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminSuperAdminDto> updateMyCredentials({
    required String currentPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    return _client.putJson<AdminSuperAdminDto>(
      'admin/me/credentials',
      {
        'current_password': currentPassword,
        'new_email': newEmail,
        'new_password': newPassword,
      },
      decode: (json) => AdminSuperAdminDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<AdminSuperAdminDto>> listSuperAdmins() async {
    return _client.getJson<List<AdminSuperAdminDto>>(
      'admin/super-admins',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(AdminSuperAdminDto.fromJson).toList();
      },
    );
  }

  Future<AdminSuperAdminDto> createSuperAdmin({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _client.postJson<AdminSuperAdminDto>(
      'admin/super-admins',
      {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
      decode: (json) => AdminSuperAdminDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> disableSuperAdmin(int userId) async {
    await _client.deleteJson<Map<String, dynamic>>(
      'admin/super-admins/$userId',
      decode: (json) => json as Map<String, dynamic>,
    );
  }

  Future<List<AdminPlanDto>> listPlans() async {
    return _client.getJson<List<AdminPlanDto>>(
      'admin/plans',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(AdminPlanDto.fromJson).toList();
      },
    );
  }

  Future<List<PermissionCatalogItemDto>> permissionsCatalog() async {
    return _client.getJson<List<PermissionCatalogItemDto>>(
      'admin/permissions',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PermissionCatalogItemDto.fromJson).toList();
      },
    );
  }

  Future<AdminPlanDto> createPlan({
    required String name,
    required int priceCents,
    required int durationDays,
    String? instapayLink,
    String? packageKey,
    String? packageName,
    int? maxUsers,
    List<String>? allowedPermKeys,
    bool isActive = true,
  }) async {
    return _client.postJson<AdminPlanDto>(
      'admin/plans',
      {
        'name': name,
        'price_cents': priceCents,
        'duration_days': durationDays,
        'instapay_link': instapayLink,
        'package_key': packageKey,
        'package_name': packageName,
        'max_users': maxUsers,
        'allowed_perm_keys': allowedPermKeys,
        'is_active': isActive,
      },
      decode: (json) => AdminPlanDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminPlanDto> updatePlan(
    int planId, {
    String? name,
    int? priceCents,
    int? durationDays,
    String? instapayLink,
    String? packageKey,
    String? packageName,
    int? maxUsers,
    List<String>? allowedPermKeys,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (priceCents != null) body['price_cents'] = priceCents;
    if (durationDays != null) body['duration_days'] = durationDays;
    if (instapayLink != null) body['instapay_link'] = instapayLink;
    if (packageKey != null) body['package_key'] = packageKey;
    if (packageName != null) body['package_name'] = packageName;
    if (maxUsers != null) body['max_users'] = maxUsers;
    if (allowedPermKeys != null) body['allowed_perm_keys'] = allowedPermKeys;
    if (isActive != null) body['is_active'] = isActive;
    return _client.putJson<AdminPlanDto>(
      'admin/plans/$planId',
      body,
      decode: (json) => AdminPlanDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminPlanDto> deletePlan(int planId) async {
    return _client.deleteJson<AdminPlanDto>(
      'admin/plans/$planId',
      decode: (json) => AdminPlanDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<AdminPaymentProofDto>> listPaymentProofs({String? status, int? officeId}) async {
    final q = <String, String>{};
    if ((status ?? '').isNotEmpty) q['status'] = status!;
    if (officeId != null) q['office_id'] = '$officeId';
    return _client.getJson<List<AdminPaymentProofDto>>(
      'admin/payment-proofs',
      query: q.isEmpty ? null : q,
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(AdminPaymentProofDto.fromJson).toList();
      },
    );
  }

  Future<AdminTrialAnalyticsDto> trialAnalytics({int days = 30}) async {
    return _client.getJson<AdminTrialAnalyticsDto>(
      'admin/analytics/trials',
      query: {'days': '$days'},
      decode: (json) => AdminTrialAnalyticsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminSubscriptionsAnalyticsDto> subscriptionsAnalytics({int days = 30}) async {
    return _client.getJson<AdminSubscriptionsAnalyticsDto>(
      'admin/analytics/subscriptions',
      query: {'days': '$days'},
      decode: (json) => AdminSubscriptionsAnalyticsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminSubscriptionsSeriesDto> subscriptionsSeries({int days = 30}) async {
    return _client.getJson<AdminSubscriptionsSeriesDto>(
      'admin/analytics/subscriptions_series',
      query: {'days': '$days'},
      decode: (json) => AdminSubscriptionsSeriesDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminAlertsDto> alerts() async {
    return _client.getJson<AdminAlertsDto>(
      'admin/alerts',
      decode: (json) => AdminAlertsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminPaymentProofDto> approvePaymentProof(int proofId, {String? decisionNotes}) async {
    return _client.postJson<AdminPaymentProofDto>(
      'admin/payment-proofs/$proofId/approve',
      {
        'decision_notes': decisionNotes,
      },
      decode: (json) => AdminPaymentProofDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<AdminPaymentProofDto> rejectPaymentProof(int proofId, {String? decisionNotes}) async {
    return _client.postJson<AdminPaymentProofDto>(
      'admin/payment-proofs/$proofId/reject',
      {
        'decision_notes': decisionNotes,
      },
      decode: (json) => AdminPaymentProofDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

class AdminPaymentProofFilesApiException implements Exception {
  AdminPaymentProofFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AdminPaymentProofFilesApi {
  AdminPaymentProofFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<(Uint8List bytes, String? contentType)> downloadProof(int proofId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw AdminPaymentProofFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('admin/payment-proofs/$proofId');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminPaymentProofFilesApiException('فشل تنزيل صورة التحويل', statusCode: res.statusCode);
    }
    return (res.bodyBytes, res.headers['content-type']);
  }
}

class AdminPlanPromoFilesApiException implements Exception {
  AdminPlanPromoFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AdminPlanPromoFilesApi {
  AdminPlanPromoFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<void> uploadPromoImage({
    required int planId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw AdminPlanPromoFilesApiException('الملف غير متاح للرفع');
    }

    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw AdminPlanPromoFilesApiException('سجّل الدخول أولاً');
    }

    final uri = ApiConfig.uri('admin/plans/$planId/promo-image');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('upload', bytes, filename: file.name));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw AdminPlanPromoFilesApiException(body.isEmpty ? 'فشل رفع الصورة' : body, statusCode: streamed.statusCode);
    }
  }

  Future<(Uint8List bytes, String? contentType)> downloadPromo(int planId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw AdminPlanPromoFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('admin/plans/$planId/promo-image');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminPlanPromoFilesApiException('فشل تنزيل صورة الباقة', statusCode: res.statusCode);
    }
    return (res.bodyBytes, res.headers['content-type']);
  }
}

