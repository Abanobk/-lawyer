import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class FinancialSummaryDto {
  FinancialSummaryDto({
    this.periodFrom,
    this.periodTo,
    this.caseIdFilter,
    required this.totalCaseIncome,
    required this.totalCaseExpense,
    required this.totalOfficeExpense,
    required this.totalCustodyAdvances,
    required this.totalCustodySpendsApproved,
    required this.totalCustodySpendsPending,
    this.totalPettyTopUps = 0,
    this.totalPettySpends = 0,
    this.totalPettySettlementNet = 0,
    required this.netCase,
    required this.netOperatingSimple,
    required this.includesCustody,
  });

  final String? periodFrom;
  final String? periodTo;
  final int? caseIdFilter;
  final double totalCaseIncome;
  final double totalCaseExpense;
  final double totalOfficeExpense;
  final double totalCustodyAdvances;
  final double totalCustodySpendsApproved;
  final double totalCustodySpendsPending;
  final double totalPettyTopUps;
  final double totalPettySpends;
  final double totalPettySettlementNet;
  final double netCase;
  final double netOperatingSimple;
  final bool includesCustody;

  factory FinancialSummaryDto.fromJson(Map<String, dynamic> json) {
    return FinancialSummaryDto(
      periodFrom: json['period_from'] as String?,
      periodTo: json['period_to'] as String?,
      caseIdFilter: json['case_id_filter'] as int?,
      totalCaseIncome: (json['total_case_income'] as num).toDouble(),
      totalCaseExpense: (json['total_case_expense'] as num).toDouble(),
      totalOfficeExpense: (json['total_office_expense'] as num).toDouble(),
      totalCustodyAdvances: (json['total_custody_advances'] as num).toDouble(),
      totalCustodySpendsApproved: (json['total_custody_spends_approved'] as num).toDouble(),
      totalCustodySpendsPending: (json['total_custody_spends_pending'] as num).toDouble(),
      totalPettyTopUps: (json['total_petty_top_ups'] as num?)?.toDouble() ?? 0,
      totalPettySpends: (json['total_petty_spends'] as num?)?.toDouble() ?? 0,
      totalPettySettlementNet: (json['total_petty_settlement_net'] as num?)?.toDouble() ?? 0,
      netCase: (json['net_case'] as num).toDouble(),
      netOperatingSimple: (json['net_operating_simple'] as num).toDouble(),
      includesCustody: json['includes_custody'] as bool,
    );
  }
}

class FinancialMovementDto {
  FinancialMovementDto({
    required this.ledgerKey,
    required this.sourceType,
    required this.sourceId,
    required this.kind,
    required this.kindLabelAr,
    required this.occurredAt,
    required this.amount,
    required this.direction,
    required this.affectsOfficeCash,
    this.caseId,
    this.caseTitle,
    this.custodyUserId,
    this.custodyUserEmail,
    this.description,
  });

  final String ledgerKey;
  final String sourceType;
  final int sourceId;
  final String kind;
  final String kindLabelAr;
  final DateTime occurredAt;
  final double amount;
  final String direction;
  final bool affectsOfficeCash;
  final int? caseId;
  final String? caseTitle;
  final int? custodyUserId;
  final String? custodyUserEmail;
  final String? description;

  factory FinancialMovementDto.fromJson(Map<String, dynamic> json) {
    return FinancialMovementDto(
      ledgerKey: json['ledger_key'] as String,
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as int,
      kind: json['kind'] as String,
      kindLabelAr: json['kind_label_ar'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      amount: (json['amount'] as num).toDouble(),
      direction: json['direction'] as String,
      affectsOfficeCash: json['affects_office_cash'] as bool,
      caseId: json['case_id'] as int?,
      caseTitle: json['case_title'] as String?,
      custodyUserId: json['custody_user_id'] as int?,
      custodyUserEmail: json['custody_user_email'] as String?,
      description: json['description'] as String?,
    );
  }
}

class IncomeStatementDto {
  IncomeStatementDto({
    required this.periodFrom,
    required this.periodTo,
    required this.revenueCaseIncome,
    required this.costsCaseExpenses,
    required this.grossMarginCases,
    required this.expenseOffice,
    required this.expensePettyTopUps,
    required this.expenseCustodyAdvances,
    required this.totalMainCashOperatingOut,
    required this.netAfterOperatingMainCash,
    required this.includesCustody,
    required this.noteAr,
  });

  final String periodFrom;
  final String periodTo;
  final double revenueCaseIncome;
  final double costsCaseExpenses;
  final double grossMarginCases;
  final double expenseOffice;
  final double expensePettyTopUps;
  final double expenseCustodyAdvances;
  final double totalMainCashOperatingOut;
  final double netAfterOperatingMainCash;
  final bool includesCustody;
  final String noteAr;

  factory IncomeStatementDto.fromJson(Map<String, dynamic> json) {
    return IncomeStatementDto(
      periodFrom: json['period_from'] as String,
      periodTo: json['period_to'] as String,
      revenueCaseIncome: (json['revenue_case_income'] as num).toDouble(),
      costsCaseExpenses: (json['costs_case_expenses'] as num).toDouble(),
      grossMarginCases: (json['gross_margin_cases'] as num).toDouble(),
      expenseOffice: (json['expense_office'] as num).toDouble(),
      expensePettyTopUps: (json['expense_petty_top_ups'] as num).toDouble(),
      expenseCustodyAdvances: (json['expense_custody_advances'] as num).toDouble(),
      totalMainCashOperatingOut: (json['total_main_cash_operating_out'] as num).toDouble(),
      netAfterOperatingMainCash: (json['net_after_operating_main_cash'] as num).toDouble(),
      includesCustody: json['includes_custody'] as bool,
      noteAr: json['note_ar'] as String,
    );
  }
}

class CashFlowDayDto {
  CashFlowDayDto({
    required this.day,
    required this.inflow,
    required this.outflow,
    required this.net,
  });

  final String day;
  final double inflow;
  final double outflow;
  final double net;

  factory CashFlowDayDto.fromJson(Map<String, dynamic> json) {
    return CashFlowDayDto(
      day: json['day'] as String,
      inflow: (json['inflow'] as num).toDouble(),
      outflow: (json['outflow'] as num).toDouble(),
      net: (json['net'] as num).toDouble(),
    );
  }
}

class CaseFinancialSummaryDto {
  CaseFinancialSummaryDto({
    required this.caseId,
    required this.caseTitle,
    this.feeTotal,
    required this.sumIncome,
    required this.sumExpense,
    required this.netCashCase,
    this.remainingFromFee,
    required this.custodySpendsApproved,
    required this.custodySpendsPending,
  });

  final int caseId;
  final String caseTitle;
  final double? feeTotal;
  final double sumIncome;
  final double sumExpense;
  final double netCashCase;
  final double? remainingFromFee;
  final double custodySpendsApproved;
  final double custodySpendsPending;

  factory CaseFinancialSummaryDto.fromJson(Map<String, dynamic> json) {
    return CaseFinancialSummaryDto(
      caseId: json['case_id'] as int,
      caseTitle: json['case_title'] as String,
      feeTotal: (json['fee_total'] as num?)?.toDouble(),
      sumIncome: (json['sum_income'] as num).toDouble(),
      sumExpense: (json['sum_expense'] as num).toDouble(),
      netCashCase: (json['net_cash_case'] as num).toDouble(),
      remainingFromFee: (json['remaining_from_fee'] as num?)?.toDouble(),
      custodySpendsApproved: (json['custody_spends_approved'] as num).toDouble(),
      custodySpendsPending: (json['custody_spends_pending'] as num).toDouble(),
    );
  }
}

class CaseFinancialReceiptDto {
  CaseFinancialReceiptDto({
    required this.source,
    required this.fileId,
    required this.spendId,
    required this.originalName,
    required this.uploadedAt,
    required this.amount,
    this.description,
    this.custodyStatus,
  });

  final String source;
  final int fileId;
  final int spendId;
  final String originalName;
  final DateTime uploadedAt;
  final double amount;
  final String? description;
  final String? custodyStatus;

  factory CaseFinancialReceiptDto.fromJson(Map<String, dynamic> json) {
    return CaseFinancialReceiptDto(
      source: json['source'] as String,
      fileId: json['file_id'] as int,
      spendId: json['spend_id'] as int,
      originalName: json['original_name'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      custodyStatus: json['custody_status'] as String?,
    );
  }
}

class CaseFinancialDocumentsDto {
  CaseFinancialDocumentsDto({required this.caseId, required this.receipts});

  final int caseId;
  final List<CaseFinancialReceiptDto> receipts;

  factory CaseFinancialDocumentsDto.fromJson(Map<String, dynamic> json) {
    final list = (json['receipts'] as List).cast<Map<String, dynamic>>();
    return CaseFinancialDocumentsDto(
      caseId: json['case_id'] as int,
      receipts: list.map(CaseFinancialReceiptDto.fromJson).toList(),
    );
  }
}

class FinanceAuditLogDto {
  FinanceAuditLogDto({
    required this.id,
    this.userId,
    required this.actionKey,
    required this.entityType,
    this.entityId,
    this.caseId,
    this.detail,
    required this.createdAt,
  });

  final int id;
  final int? userId;
  final String actionKey;
  final String entityType;
  final int? entityId;
  final int? caseId;
  final Map<String, dynamic>? detail;
  final DateTime createdAt;

  factory FinanceAuditLogDto.fromJson(Map<String, dynamic> json) {
    return FinanceAuditLogDto(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      actionKey: json['action_key'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as int?,
      caseId: json['case_id'] as int?,
      detail: json['detail'] == null ? null : Map<String, dynamic>.from(json['detail'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FinanceApi {
  FinanceApi({ApiClient? client, http.Client? httpClient, AuthTokenStorage? tokens})
      : _client = client ?? ApiClient(),
        _http = httpClient ?? http.Client(),
        _tokens = tokens ?? AuthTokenStorage();
  final ApiClient _client;
  final http.Client _http;
  final AuthTokenStorage _tokens;

  Map<String, String> _rangeQuery(DateTime from, DateTime to, {int? caseId}) {
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final q = <String, String>{'from': d(from), 'to': d(to)};
    if (caseId != null) q['case_id'] = '$caseId';
    return q;
  }

  Future<FinancialSummaryDto> summary({
    required DateTime from,
    required DateTime to,
    int? caseId,
  }) async {
    return _client.getJson<FinancialSummaryDto>(
      'finance/summary',
      query: _rangeQuery(from, to, caseId: caseId),
      decode: (json) => FinancialSummaryDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<FinancialMovementDto>> movements({
    required DateTime from,
    required DateTime to,
    int? caseId,
    int limit = 400,
    int offset = 0,
  }) async {
    final q = _rangeQuery(from, to, caseId: caseId);
    q['limit'] = '$limit';
    q['offset'] = '$offset';
    return _client.getJson<List<FinancialMovementDto>>(
      'finance/movements',
      query: q,
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(FinancialMovementDto.fromJson).toList();
      },
    );
  }

  Future<String> movementsCsv({
    required DateTime from,
    required DateTime to,
    int? caseId,
  }) async {
    return _client.getUtf8Text(
      'finance/movements/export',
      query: _rangeQuery(from, to, caseId: caseId),
    );
  }

  Future<IncomeStatementDto> incomeStatement({required DateTime from, required DateTime to}) async {
    return _client.getJson<IncomeStatementDto>(
      'finance/income-statement',
      query: _rangeQuery(from, to),
      decode: (json) => IncomeStatementDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<CashFlowDayDto>> cashFlowDaily({required DateTime from, required DateTime to}) async {
    return _client.getJson<List<CashFlowDayDto>>(
      'finance/cash-flow-daily',
      query: _rangeQuery(from, to),
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CashFlowDayDto.fromJson).toList();
      },
    );
  }

  Future<CaseFinancialSummaryDto> caseFinancialSummary(int caseId) async {
    return _client.getJson<CaseFinancialSummaryDto>(
      'finance/cases/$caseId/summary',
      decode: (json) => CaseFinancialSummaryDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CaseFinancialDocumentsDto> caseFinancialDocuments(int caseId) async {
    return _client.getJson<CaseFinancialDocumentsDto>(
      'finance/cases/$caseId/documents',
      decode: (json) => CaseFinancialDocumentsDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<FinanceAuditLogDto>> financeAuditLog({int limit = 200}) async {
    return _client.getJson<List<FinanceAuditLogDto>>(
      'finance/audit-log',
      query: {'limit': '$limit'},
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(FinanceAuditLogDto.fromJson).toList();
      },
    );
  }

  Future<(Uint8List bytes, String contentType)> downloadPettyReceipt(int fileId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('petty-cash/receipts/$fileId');
    final res = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(_parseFinanceErr(res.bodyBytes));
    }
    final ct = res.headers['content-type'] ?? 'application/octet-stream';
    return (res.bodyBytes, ct);
  }

  Future<(Uint8List bytes, String contentType)> downloadCustodyReceiptForCase(int fileId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('finance/custody-receipts/$fileId');
    final res = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(_parseFinanceErr(res.bodyBytes));
    }
    final ct = res.headers['content-type'] ?? 'application/octet-stream';
    return (res.bodyBytes, ct);
  }

  String _parseFinanceErr(Uint8List body) {
    try {
      final t = utf8.decode(body);
      final map = jsonDecode(t);
      if (map is Map<String, dynamic> && map['detail'] is String) return map['detail'] as String;
      return t.isEmpty ? 'فشل الطلب' : t;
    } catch (_) {
      return 'فشل الطلب';
    }
  }
}
