import 'package:lawyer_app/data/api/api_client.dart';

class SessionDto {
  SessionDto({
    required this.id,
    required this.caseId,
    required this.caseTitle,
    required this.clientName,
    this.sessionNumber,
    this.sessionYear,
    required this.sessionDate,
    this.notes,
    required this.createdAt,
  });

  final int id;
  final int caseId;
  final String caseTitle;
  final String clientName;
  final String? sessionNumber;
  final int? sessionYear;
  final DateTime sessionDate;
  final String? notes;
  final DateTime createdAt;

  factory SessionDto.fromJson(Map<String, dynamic> json) {
    return SessionDto(
      id: json['id'] as int,
      caseId: json['case_id'] as int,
      caseTitle: json['case_title'] as String,
      clientName: json['client_name'] as String,
      sessionNumber: json['session_number'] as String?,
      sessionYear: json['session_year'] as int?,
      sessionDate: DateTime.parse(json['session_date'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionsApi {
  SessionsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<SessionDto>> list() async {
    return _client.getJson<List<SessionDto>>(
      'sessions',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(SessionDto.fromJson).toList();
      },
    );
  }

  Future<SessionDto> reschedule({
    required int sessionId,
    required DateTime newDate,
    String? notes,
  }) async {
    return _client.putJson<SessionDto>(
      'sessions/$sessionId',
      {
        'session_date': newDate.toUtc().toIso8601String(),
        'notes': notes,
      },
      decode: (json) => SessionDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

