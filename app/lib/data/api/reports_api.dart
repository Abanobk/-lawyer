import 'package:lawyer_app/data/api/api_client.dart';

class ClientCaseAccountReportItemDto {
  ClientCaseAccountReportItemDto({
    required this.caseId,
    required this.caseTitle,
    this.feeTotal,
    required this.incomeSum,
    this.remaining,
  });

  final int caseId;
  final String caseTitle;
  final double? feeTotal;
  final double incomeSum;
  final double? remaining;

  factory ClientCaseAccountReportItemDto.fromJson(Map<String, dynamic> json) {
    return ClientCaseAccountReportItemDto(
      caseId: json['case_id'] as int,
      caseTitle: json['case_title'] as String,
      feeTotal: (json['fee_total'] as num?)?.toDouble(),
      incomeSum: (json['income_sum'] as num).toDouble(),
      remaining: (json['remaining'] as num?)?.toDouble(),
    );
  }
}

class ClientAccountReportDto {
  ClientAccountReportDto({
    required this.clientId,
    required this.clientName,
    required this.cases,
  });

  final int clientId;
  final String clientName;
  final List<ClientCaseAccountReportItemDto> cases;

  factory ClientAccountReportDto.fromJson(Map<String, dynamic> json) {
    final list = (json['cases'] as List).cast<Map<String, dynamic>>();
    return ClientAccountReportDto(
      clientId: json['client_id'] as int,
      clientName: json['client_name'] as String,
      cases: list.map(ClientCaseAccountReportItemDto.fromJson).toList(),
    );
  }
}

class CustodyReportItemDto {
  CustodyReportItemDto({
    required this.userId,
    required this.userEmail,
    required this.currentBalance,
    required this.advancesSum,
    required this.approvedSpendsSum,
    required this.pendingSpendsSum,
  });

  final int userId;
  final String userEmail;
  final double currentBalance;
  final double advancesSum;
  final double approvedSpendsSum;
  final double pendingSpendsSum;

  factory CustodyReportItemDto.fromJson(Map<String, dynamic> json) {
    return CustodyReportItemDto(
      userId: json['user_id'] as int,
      userEmail: json['user_email'] as String,
      currentBalance: (json['current_balance'] as num).toDouble(),
      advancesSum: (json['advances_sum'] as num).toDouble(),
      approvedSpendsSum: (json['approved_spends_sum'] as num).toDouble(),
      pendingSpendsSum: (json['pending_spends_sum'] as num).toDouble(),
    );
  }
}

class ReportsApi {
  ReportsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<ClientAccountReportDto> clientAccount(int clientId) async {
    return _client.getJson<ClientAccountReportDto>(
      'reports/client/$clientId',
      decode: (json) => ClientAccountReportDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<CustodyReportItemDto>> custody({int? userId}) async {
    final path = userId == null ? 'reports/custody' : 'reports/custody?user_id=$userId';
    return _client.getJson<List<CustodyReportItemDto>>(
      path,
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CustodyReportItemDto.fromJson).toList();
      },
    );
  }
}

