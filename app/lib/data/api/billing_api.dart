import 'package:lawyer_app/data/api/api_client.dart';

class SubscriptionMeDto {
  SubscriptionMeDto({
    required this.status,
    required this.startAt,
    required this.endAt,
    this.maxUsersEffective,
    this.maxUsersOverride,
  });

  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final int? maxUsersEffective;
  final int? maxUsersOverride;

  factory SubscriptionMeDto.fromJson(Map<String, dynamic> json) {
    return SubscriptionMeDto(
      status: json['status'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      maxUsersEffective: (json['max_users_effective'] as num?)?.toInt(),
      maxUsersOverride: (json['max_users_override'] as num?)?.toInt(),
    );
  }
}

class BillingApi {
  BillingApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<SubscriptionMeDto> subscriptionMe() async {
    return _client.getJson<SubscriptionMeDto>(
      'billing/status',
      decode: (json) => SubscriptionMeDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

