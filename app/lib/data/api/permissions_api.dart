import 'package:lawyer_app/data/api/api_client.dart';

class PermissionCatalogItemDto {
  PermissionCatalogItemDto({required this.key, required this.label});
  final String key;
  final String label;

  factory PermissionCatalogItemDto.fromJson(Map<String, dynamic> json) {
    return PermissionCatalogItemDto(
      key: json['key'] as String,
      label: json['label'] as String,
    );
  }
}

class UserPermissionsDto {
  UserPermissionsDto({required this.userId, required this.permissions});
  final int userId;
  final List<String> permissions;

  factory UserPermissionsDto.fromJson(Map<String, dynamic> json) {
    return UserPermissionsDto(
      userId: json['user_id'] as int,
      permissions: (json['permissions'] as List).cast<String>(),
    );
  }
}

class PermissionsApi {
  PermissionsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<PermissionCatalogItemDto>> catalog() async {
    return _client.getJson<List<PermissionCatalogItemDto>>(
      'office/permissions',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PermissionCatalogItemDto.fromJson).toList();
      },
    );
  }

  Future<UserPermissionsDto> getForUser(int userId) async {
    return _client.getJson<UserPermissionsDto>(
      'office/users/$userId/permissions',
      decode: (json) => UserPermissionsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<UserPermissionsDto> myPermissions() async {
    return _client.getJson<UserPermissionsDto>(
      'me/permissions',
      decode: (json) => UserPermissionsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<UserPermissionsDto> setForUser(int userId, List<String> permissions) async {
    return _client.putJson<UserPermissionsDto>(
      'office/users/$userId/permissions',
      {'permissions': permissions},
      decode: (json) => UserPermissionsDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

