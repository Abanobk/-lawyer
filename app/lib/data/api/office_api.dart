import 'package:lawyer_app/data/api/api_client.dart';

class OfficeUserDto {
  OfficeUserDto({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String role;
  final DateTime createdAt;

  factory OfficeUserDto.fromJson(Map<String, dynamic> json) {
    return OfficeUserDto(
      id: json['id'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OfficeUserCreateOutDto {
  OfficeUserCreateOutDto({
    required this.id,
    required this.email,
    required this.role,
    required this.tempPassword,
  });

  final int id;
  final String email;
  final String role;
  final String tempPassword;

  factory OfficeUserCreateOutDto.fromJson(Map<String, dynamic> json) {
    return OfficeUserCreateOutDto(
      id: json['id'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      tempPassword: json['temp_password'] as String,
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

  Future<OfficeUserCreateOutDto> createUser({required String email}) async {
    return _client.postJson<OfficeUserCreateOutDto>(
      'office/users',
      {'email': email},
      decode: (json) => OfficeUserCreateOutDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

