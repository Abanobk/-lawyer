import 'package:lawyer_app/data/api/api_client.dart';

class CaseDto {
  CaseDto({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.kind,
    this.court,
    this.caseNumber,
    this.caseYear,
    this.firstHearingAt,
    this.feeTotal,
    required this.isActive,
    this.primaryLawyerUserId,
    this.primaryLawyerEmail,
    required this.createdAt,
  });

  final int id;
  final int clientId;
  final String clientName;
  final String title;
  final String kind;
  final String? court;
  final String? caseNumber;
  final int? caseYear;
  final DateTime? firstHearingAt;
  final double? feeTotal;
  final bool isActive;
  final int? primaryLawyerUserId;
  final String? primaryLawyerEmail;
  final DateTime createdAt;

  factory CaseDto.fromJson(Map<String, dynamic> json) {
    return CaseDto(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String,
      court: json['court'] as String?,
      caseNumber: json['case_number'] as String?,
      caseYear: json['case_year'] as int?,
      firstHearingAt: json['first_hearing_at'] == null
          ? null
          : DateTime.parse(json['first_hearing_at'] as String),
      feeTotal: (json['fee_total'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool,
      primaryLawyerUserId: json['primary_lawyer_user_id'] as int?,
      primaryLawyerEmail: json['primary_lawyer_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CasesApi {
  CasesApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<CaseDto>> list({int? clientId}) async {
    final q = clientId == null ? 'cases' : 'cases?client_id=$clientId';
    return _client.getJson<List<CaseDto>>(
      q,
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CaseDto.fromJson).toList();
      },
    );
  }

  Future<CaseDto> create({
    required int clientId,
    required String title,
    required String kind,
    String? court,
    String? caseNumber,
    int? caseYear,
    DateTime? firstHearingAt,
    double? feeTotal,
    int? primaryLawyerUserId,
    String? firstSessionNumber,
    int? firstSessionYear,
  }) async {
    return _client.postJson<CaseDto>(
      'cases',
      {
        'client_id': clientId,
        'title': title,
        'kind': kind,
        'court': court,
        'case_number': caseNumber,
        'case_year': caseYear,
        'first_hearing_at': firstHearingAt?.toUtc().toIso8601String(),
        'fee_total': feeTotal,
        'primary_lawyer_user_id': primaryLawyerUserId,
        'first_session_number': firstSessionNumber,
        'first_session_year': firstSessionYear,
      },
      decode: (json) => CaseDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

