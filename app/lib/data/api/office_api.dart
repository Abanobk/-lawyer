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

class OfficeApi {
  OfficeApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<OfficeUserDto>> users() async {
    return _client.getJson<List<OfficeUserDto>>(
      'office/users',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(OfficeUserDto.fromJson).toList();
      },
    );
  }
}

