import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class PettyCashFundDto {
  PettyCashFundDto({
    required this.id,
    required this.name,
    required this.receiptRequiredAbove,
    required this.currentBalance,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final double receiptRequiredAbove;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;

  factory PettyCashFundDto.fromJson(Map<String, dynamic> json) {
    return PettyCashFundDto(
      id: json['id'] as int,
      name: json['name'] as String,
      receiptRequiredAbove: (json['receipt_required_above'] as num).toDouble(),
      currentBalance: (json['current_balance'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PettyCashSpendDto {
  PettyCashSpendDto({
    required this.id,
    required this.fundId,
    required this.amount,
    this.description,
    required this.occurredAt,
    this.caseId,
    this.createdByUserId,
    required this.createdAt,
  });

  final int id;
  final int fundId;
  final double amount;
  final String? description;
  final DateTime occurredAt;
  final int? caseId;
  final int? createdByUserId;
  final DateTime createdAt;

  factory PettyCashSpendDto.fromJson(Map<String, dynamic> json) {
    return PettyCashSpendDto(
      id: json['id'] as int,
      fundId: json['fund_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      caseId: json['case_id'] as int?,
      createdByUserId: json['created_by_user_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PettyCashPeriodReportDto {
  PettyCashPeriodReportDto({
    required this.fundId,
    required this.fundName,
    required this.currentBalance,
    required this.periodFrom,
    required this.periodTo,
    required this.sumTopUps,
    required this.sumSpends,
    required this.sumSettlements,
    required this.netChange,
    required this.openingBalance,
    required this.closingBalanceImplied,
  });

  final int fundId;
  final String fundName;
  final double currentBalance;
  final String periodFrom;
  final String periodTo;
  final double sumTopUps;
  final double sumSpends;
  final double sumSettlements;
  final double netChange;
  final double openingBalance;
  final double closingBalanceImplied;

  factory PettyCashPeriodReportDto.fromJson(Map<String, dynamic> json) {
    return PettyCashPeriodReportDto(
      fundId: json['fund_id'] as int,
      fundName: json['fund_name'] as String,
      currentBalance: (json['current_balance'] as num).toDouble(),
      periodFrom: json['period_from'] as String,
      periodTo: json['period_to'] as String,
      sumTopUps: (json['sum_top_ups'] as num).toDouble(),
      sumSpends: (json['sum_spends'] as num).toDouble(),
      sumSettlements: (json['sum_settlements'] as num).toDouble(),
      netChange: (json['net_change'] as num).toDouble(),
      openingBalance: (json['opening_balance'] as num).toDouble(),
      closingBalanceImplied: (json['closing_balance_implied'] as num).toDouble(),
    );
  }
}

class PettyCashApi {
  PettyCashApi({ApiClient? client, http.Client? httpClient, AuthTokenStorage? tokens})
      : _client = client ?? ApiClient(),
        _http = httpClient ?? http.Client(),
        _tokens = tokens ?? AuthTokenStorage();

  final ApiClient _client;
  final http.Client _http;
  final AuthTokenStorage _tokens;

  Future<List<PettyCashFundDto>> listFunds() async {
    return _client.getJson<List<PettyCashFundDto>>(
      'petty-cash/funds',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PettyCashFundDto.fromJson).toList();
      },
    );
  }

  Future<PettyCashFundDto> createFund({required String name, double receiptRequiredAbove = 0}) async {
    return _client.postJson<PettyCashFundDto>(
      'petty-cash/funds',
      {'name': name, 'receipt_required_above': receiptRequiredAbove},
      decode: (json) => PettyCashFundDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<PettyCashFundDto> patchFund(int fundId, {String? name, double? receiptRequiredAbove, bool? isActive}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (receiptRequiredAbove != null) body['receipt_required_above'] = receiptRequiredAbove;
    if (isActive != null) body['is_active'] = isActive;
    return _client.patchJson<PettyCashFundDto>(
      'petty-cash/funds/$fundId',
      body,
      decode: (json) => PettyCashFundDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> addTopUp(int fundId, {required double amount, String? notes}) async {
    await _client.postJson<Map<String, dynamic>>(
      'petty-cash/funds/$fundId/top-ups',
      {'amount': amount, if (notes != null && notes.isNotEmpty) 'notes': notes},
      decode: (json) => json as Map<String, dynamic>,
    );
  }

  Future<void> addSettlement(int fundId, {required double adjustmentAmount, String? notes}) async {
    await _client.postJson<Map<String, dynamic>>(
      'petty-cash/funds/$fundId/settlements',
      {'adjustment_amount': adjustmentAmount, if (notes != null && notes.isNotEmpty) 'notes': notes},
      decode: (json) => json as Map<String, dynamic>,
    );
  }

  Future<List<PettyCashSpendDto>> listSpends(int fundId) async {
    return _client.getJson<List<PettyCashSpendDto>>(
      'petty-cash/funds/$fundId/spends',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PettyCashSpendDto.fromJson).toList();
      },
    );
  }

  Future<PettyCashPeriodReportDto> periodReport(int fundId, {required DateTime from, required DateTime to}) async {
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return _client.getJson<PettyCashPeriodReportDto>(
      'petty-cash/funds/$fundId/period-report',
      query: {'from': d(from), 'to': d(to)},
      decode: (json) => PettyCashPeriodReportDto.fromJson(json as Map<String, dynamic>),
    );
  }

  /// رفع إيصال لاحقاً (حقل الملف في الـ API: `receipt`).
  Future<void> uploadReceipt({required int spendId, required PlatformFile file}) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw StateError('الملف غير متاح');
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) throw StateError('سجّل الدخول أولاً');
    final uri = ApiConfig.uri('petty-cash/spends/$spendId/receipts');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('upload', bytes, filename: file.name));
    final streamed = await _http.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError(body.isEmpty ? 'فشل رفع الإيصال' : body);
    }
  }

  Future<PettyCashSpendDto> createSpend({
    required int fundId,
    required double amount,
    String? description,
    int? caseId,
    PlatformFile? receipt,
  }) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) throw StateError('سجّل الدخول أولاً');
    final uri = ApiConfig.uri('petty-cash/funds/$fundId/spends');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['amount'] = amount.toString();
    if (description != null && description.isNotEmpty) req.fields['description'] = description;
    if (caseId != null) req.fields['case_id'] = '$caseId';
    final rec = receipt;
    if (rec != null && rec.bytes != null && rec.bytes!.isNotEmpty) {
      req.files.add(http.MultipartFile.fromBytes('receipt', rec.bytes!, filename: rec.name));
    }
    final streamed = await _http.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw StateError(body.isEmpty ? 'فشل تسجيل الصرف' : body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return PettyCashSpendDto.fromJson(json);
  }
}
