import 'package:lawyer_app/data/api/api_client.dart';

class OfficeUserDto {
  OfficeUserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final String role;
  final DateTime createdAt;

  factory OfficeUserDto.fromJson(Map<String, dynamic> json) {
    return OfficeUserDto(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OfficeUserCreateOutDto {
  OfficeUserCreateOutDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.role,
  });

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final String role;

  factory OfficeUserCreateOutDto.fromJson(Map<String, dynamic> json) {
    return OfficeUserCreateOutDto(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      role: json['role'] as String,
    );
  }
}

class OfficeApi {
  OfficeApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<({int id, String code, String name})> myOffice() async {
    return _client.getJson<({int id, String code, String name})>(
      'office',
      decode: (json) {
        final m = json as Map<String, dynamic>;
        return (
          id: m['id'] as int,
          code: m['code'] as String,
          name: m['name'] as String,
        );
      },
    );
  }

  Future<List<OfficeUserDto>> users() async {
    return _client.getJson<List<OfficeUserDto>>(
      'office/users',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(OfficeUserDto.fromJson).toList();
      },
    );
  }

  Future<OfficeUserCreateOutDto> createUser({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _client.postJson<OfficeUserCreateOutDto>(
      'office/users',
      {
        'full_name': fullName,
        'email': email,
        'password': password,
      },
      decode: (json) => OfficeUserCreateOutDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> disableUser(int userId) async {
    await _client.deleteJson<Map<String, dynamic>>(
      'office/users/$userId',
      decode: (json) => json as Map<String, dynamic>,
    );
  }
}

