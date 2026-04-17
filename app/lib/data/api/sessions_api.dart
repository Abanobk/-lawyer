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
    this.feeReminderAmount,
    this.feeReminderDueAt,
    this.feeReminderNote,
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
  final double? feeReminderAmount;
  final DateTime? feeReminderDueAt;
  final String? feeReminderNote;
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
      feeReminderAmount: (json['fee_reminder_amount'] as num?)?.toDouble(),
      feeReminderDueAt: json['fee_reminder_due_at'] == null
          ? null
          : DateTime.parse(json['fee_reminder_due_at'] as String),
      feeReminderNote: json['fee_reminder_note'] as String?,
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

  Future<SessionDto> create({
    required int caseId,
    required DateTime sessionDate,
    String? sessionNumber,
    int? sessionYear,
    String? notes,
    double? feeReminderAmount,
    DateTime? feeReminderDueAt,
    String? feeReminderNote,
  }) async {
    return _client.postJson<SessionDto>(
      'sessions',
      {
        'case_id': caseId,
        'session_date': sessionDate.toUtc().toIso8601String(),
        'session_number': sessionNumber,
        'session_year': sessionYear,
        'notes': notes,
        'fee_reminder_amount': feeReminderAmount,
        'fee_reminder_due_at': feeReminderDueAt?.toUtc().toIso8601String(),
        'fee_reminder_note': feeReminderNote,
      },
      decode: (json) => SessionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> deleteSession(int sessionId) async {
    await _client.deleteJson<Map<String, dynamic>>(
      'sessions/$sessionId',
      decode: (json) => json as Map<String, dynamic>,
    );
  }

  Future<SessionDto> reschedule({
    required int sessionId,
    required DateTime newDate,
    String? notes,
  }) async {
    return update(
      sessionId: sessionId,
      sessionDate: newDate,
      notes: notes,
    );
  }

  Future<SessionDto> update({
    required int sessionId,
    DateTime? sessionDate,
    String? sessionNumber,
    int? sessionYear,
    String? notes,
    bool patchFeeReminder = false,
    double? feeReminderAmount,
    DateTime? feeReminderDueAt,
    String? feeReminderNote,
    bool feeReminderDueCleared = false,
  }) async {
    final body = <String, dynamic>{
      'session_date': sessionDate?.toUtc().toIso8601String(),
      'session_number': sessionNumber,
      'session_year': sessionYear,
      'notes': notes,
    };
    if (patchFeeReminder) {
      body['fee_reminder_note'] = feeReminderNote;
      body['fee_reminder_amount'] = feeReminderAmount;
      if (feeReminderDueCleared) {
        body['fee_reminder_due_at'] = null;
      } else if (feeReminderDueAt != null) {
        body['fee_reminder_due_at'] = feeReminderDueAt.toUtc().toIso8601String();
      }
    }
    return _client.putJson<SessionDto>(
      'sessions/$sessionId',
      body,
      decode: (json) => SessionDto.fromJson(json as Map<String, dynamic>),
    );
  }
}

