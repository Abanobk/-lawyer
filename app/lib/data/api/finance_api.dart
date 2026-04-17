import 'package:lawyer_app/data/api/api_client.dart';

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

class FinanceApi {
  FinanceApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

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
}
