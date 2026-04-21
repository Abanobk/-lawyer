import 'package:lawyer_app/data/api/api_client.dart';

class CaseTransactionDto {
  CaseTransactionDto({
    required this.id,
    required this.caseId,
    required this.direction,
    required this.amount,
    this.description,
    required this.occurredAt,
    required this.createdAt,
  });

  final int id;
  final int caseId;
  final String direction; // income | expense
  final double amount;
  final String? description;
  final DateTime occurredAt;
  final DateTime createdAt;

  factory CaseTransactionDto.fromJson(Map<String, dynamic> json) {
    return CaseTransactionDto(
      id: json['id'] as int,
      caseId: json['case_id'] as int,
      direction: json['direction'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TransactionsApi {
  TransactionsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<CaseTransactionDto>> listForCase(int caseId) async {
    return _client.getJson<List<CaseTransactionDto>>(
      'cases/$caseId/transactions',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CaseTransactionDto.fromJson).toList();
      },
    );
  }

  Future<CaseTransactionDto> create({
    required int caseId,
    required String direction,
    required double amount,
    String? description,
    DateTime? occurredAt,
  }) async {
    final desc = description?.trim();
    return _client.postJson<CaseTransactionDto>(
      'transactions',
      {
        'case_id': caseId,
        'direction': direction.trim(),
        'amount': amount,
        ...?((desc != null && desc.isNotEmpty) ? {'description': desc} : null),
        ...?((occurredAt != null) ? {'occurred_at': occurredAt.toUtc().toIso8601String()} : null),
      },
      decode: (json) => CaseTransactionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CaseTransactionDto> update({
    required int transactionId,
    String? direction,
    double? amount,
    String? description,
    DateTime? occurredAt,
  }) async {
    final dir = direction?.trim();
    final desc = description?.trim();
    final body = <String, dynamic>{
      ...?((dir != null && dir.isNotEmpty) ? {'direction': dir} : null),
      ...?((amount != null) ? {'amount': amount} : null),
      ...?((desc != null && desc.isNotEmpty) ? {'description': desc} : null),
      ...?((occurredAt != null) ? {'occurred_at': occurredAt.toUtc().toIso8601String()} : null),
    };
    return _client.putJson<CaseTransactionDto>(
      'transactions/$transactionId',
      body,
      decode: (json) => CaseTransactionDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> delete(int transactionId) async {
    await _client.deleteJson<Map<String, dynamic>>(
      'transactions/$transactionId',
      decode: (json) => json as Map<String, dynamic>,
    );
  }
}

