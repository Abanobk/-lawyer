import 'package:lawyer_app/data/api/api_client.dart';

class PlanDto {
  PlanDto({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.durationDays,
    this.instapayLink,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int priceCents;
  final int durationDays;
  final String? instapayLink;
  final bool isActive;
  final DateTime createdAt;

  factory PlanDto.fromJson(Map<String, dynamic> json) {
    return PlanDto(
      id: json['id'] as int,
      name: json['name'] as String,
      priceCents: json['price_cents'] as int,
      durationDays: json['duration_days'] as int,
      instapayLink: json['instapay_link'] as String?,
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

