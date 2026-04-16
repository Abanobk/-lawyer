import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class CustodyAccountDto {
  CustodyAccountDto({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.currentBalance,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userEmail;
  final double currentBalance;
  final DateTime createdAt;

  factory CustodyAccountDto.fromJson(Map<String, dynamic> json) {
    return CustodyAccountDto(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userEmail: json['user_email'] as String,
      currentBalance: (json['current_balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CustodySpendDto {
  CustodySpendDto({
    required this.id,
    required this.userId,
    required this.amount,
    required this.occurredAt,
    this.description,
    required this.status,
    this.caseId,
    this.rejectReason,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String status;
  final int? caseId;
  final String? rejectReason;
  final DateTime createdAt;

  factory CustodySpendDto.fromJson(Map<String, dynamic> json) {
    return CustodySpendDto(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      description: json['description'] as String?,
      status: json['status'] as String,
      caseId: json['case_id'] as int?,
      rejectReason: json['reject_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CustodyLedgerEntryDto {
  CustodyLedgerEntryDto({
    required this.kind,
    required this.amount,
    required this.occurredAt,
    this.description,
    this.status,
    this.spendId,
  });

  final String kind; // advance | spend
  final double amount;
  final DateTime occurredAt;
  final String? description;
  final String? status;
  final int? spendId;

  factory CustodyLedgerEntryDto.fromJson(Map<String, dynamic> json) {
    return CustodyLedgerEntryDto(
      kind: json['kind'] as String,
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      description: json['description'] as String?,
      status: json['status'] as String?,
      spendId: json['spend_id'] as int?,
    );
  }
}

class CustodyReceiptDto {
  CustodyReceiptDto({
    required this.id,
    required this.spendId,
    required this.originalName,
    this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final int id;
  final int spendId;
  final String originalName;
  final String? contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  factory CustodyReceiptDto.fromJson(Map<String, dynamic> json) {
    return CustodyReceiptDto(
      id: json['id'] as int,
      spendId: json['spend_id'] as int,
      originalName: json['original_name'] as String,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class CustodyApi {
  CustodyApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<CustodyAccountDto> myAccount() async {
    return _client.getJson<CustodyAccountDto>(
      'custody/me',
      decode: (json) => CustodyAccountDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<CustodyLedgerEntryDto>> myLedger() async {
    return _client.getJson<List<CustodyLedgerEntryDto>>(
      'custody/me/ledger',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CustodyLedgerEntryDto.fromJson).toList();
      },
    );
  }

  Future<List<CustodyAccountDto>> listAccounts() async {
    return _client.getJson<List<CustodyAccountDto>>(
      'custody/accounts',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CustodyAccountDto.fromJson).toList();
      },
    );
  }

  Future<CustodyAccountDto> createAccount({
    required int userId,
    double? initialAmount,
  }) async {
    return _client.postJson<CustodyAccountDto>(
      'custody/accounts',
      {
        'user_id': userId,
        'initial_amount': initialAmount,
      },
      decode: (json) => CustodyAccountDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CustodyAccountDto> addAdvance({
    required int userId,
    required double amount,
    required DateTime occurredAt,
    String? notes,
  }) async {
    return _client.postJson<CustodyAccountDto>(
      'custody/advances',
      {
        'user_id': userId,
        'amount': amount,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'notes': notes,
      },
      decode: (json) => CustodyAccountDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CustodySpendDto> createSpend({
    required double amount,
    required DateTime occurredAt,
    String? description,
    int? caseId,
  }) async {
    return _client.postJson<CustodySpendDto>(
      'custody/spends',
      {
        'amount': amount,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'description': description,
        'case_id': caseId,
      },
      decode: (json) => CustodySpendDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<CustodySpendDto>> listSpendsAdmin() async {
    return _client.getJson<List<CustodySpendDto>>(
      'custody/spends',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CustodySpendDto.fromJson).toList();
      },
    );
  }

  Future<CustodySpendDto> approveSpend(int spendId) async {
    return _client.postJson<CustodySpendDto>(
      'custody/spends/$spendId/approve',
      {},
      decode: (json) => CustodySpendDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CustodySpendDto> rejectSpend(int spendId, {String? reason}) async {
    return _client.postJson<CustodySpendDto>(
      'custody/spends/$spendId/reject',
      {'reject_reason': reason},
      decode: (json) => CustodySpendDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<CustodyReceiptDto>> listReceipts(int spendId) async {
    return _client.getJson<List<CustodyReceiptDto>>(
      'custody/spends/$spendId/receipts',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(CustodyReceiptDto.fromJson).toList();
      },
    );
  }
}

class CustodyFilesApiException implements Exception {
  CustodyFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class CustodyFilesApi {
  CustodyFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<void> uploadReceipt({
    required int spendId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw CustodyFilesApiException('الملف غير متاح للرفع');
    }
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CustodyFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('custody/spends/$spendId/receipts');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('upload', bytes, filename: file.name));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw CustodyFilesApiException(_parseError(body), statusCode: streamed.statusCode);
    }
  }

  Future<(Uint8List bytes, String contentType)> downloadReceipt(int fileId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CustodyFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('custody/receipts/$fileId');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CustodyFilesApiException(_parseError(utf8.decode(res.bodyBytes)), statusCode: res.statusCode);
    }
    final ct = res.headers['content-type'] ?? 'application/octet-stream';
    return (res.bodyBytes, ct);
  }

  String _parseError(String body) {
    try {
      final map = jsonDecode(body);
      if (map is Map<String, dynamic> && map['detail'] is String) return map['detail'] as String;
    } catch (_) {}
    return 'فشل الطلب';
  }
}

