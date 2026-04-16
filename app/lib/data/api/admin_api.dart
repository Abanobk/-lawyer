import 'package:lawyer_app/data/api/api_client.dart';

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
  });

  final int id;
  final int officeId;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String? planNameSnapshot;
  final int? priceSnapshotCents;
  final String? notes;

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
}

