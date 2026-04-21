import 'package:lawyer_app/data/api/api_client.dart';

class MeDto {
  MeDto({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    required this.officeId,
  });

  final int id;
  final String email;
  final String? fullName;
  final String role;
  final int? officeId;

  factory MeDto.fromJson(Map<String, dynamic> json) {
    return MeDto(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String,
      officeId: json['office_id'] as int?,
    );
  }
}

class MeApi {
  MeApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<MeDto> me() async {
    return _client.getJson<MeDto>(
      'me',
      decode: (json) => MeDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<MeDto> patchProfile({String? fullName}) async {
    final name = fullName?.trim();
    return _client.patchJson<MeDto>(
      'me',
      {if (name != null && name.isNotEmpty) 'full_name': name},
      decode: (json) => MeDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

