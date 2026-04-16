import 'package:lawyer_app/data/api/api_client.dart';

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

