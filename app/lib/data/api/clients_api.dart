import 'package:lawyer_app/data/api/api_client.dart';

class ClientDto {
  ClientDto({
    required this.id,
    required this.fullName,
    this.phone,
    this.nationalId,
    this.address,
    this.notes,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String? phone;
  final String? nationalId;
  final String? address;
  final String? notes;
  final DateTime createdAt;

  factory ClientDto.fromJson(Map<String, dynamic> json) {
    return ClientDto(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      nationalId: json['national_id'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ClientsApi {
  ClientsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<ClientDto>> list() async {
    return _client.getJson<List<ClientDto>>(
      'clients',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(ClientDto.fromJson).toList();
      },
    );
  }

  Future<ClientDto> create({
    required String fullName,
    String? phone,
    String? nationalId,
    String? address,
    String? notes,
  }) async {
    return _client.postJson<ClientDto>(
      'clients',
      {
        'full_name': fullName,
        'phone': phone,
        'national_id': nationalId,
        'address': address,
        'notes': notes,
      },
      decode: (json) => ClientDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

