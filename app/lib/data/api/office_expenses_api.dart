import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class OfficeExpenseDto {
  OfficeExpenseDto({
    required this.id,
    required this.amount,
    this.description,
    required this.occurredAt,
    this.createdByUserId,
    required this.createdAt,
  });

  final int id;
  final double amount;
  final String? description;
  final DateTime occurredAt;
  final int? createdByUserId;
  final DateTime createdAt;

  factory OfficeExpenseDto.fromJson(Map<String, dynamic> json) {
    return OfficeExpenseDto(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdByUserId: json['created_by_user_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OfficeExpenseReceiptDto {
  OfficeExpenseReceiptDto({
    required this.id,
    required this.expenseId,
    required this.originalName,
    this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final int id;
  final int expenseId;
  final String originalName;
  final String? contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  factory OfficeExpenseReceiptDto.fromJson(Map<String, dynamic> json) {
    return OfficeExpenseReceiptDto(
      id: json['id'] as int,
      expenseId: json['expense_id'] as int,
      originalName: json['original_name'] as String,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class OfficeExpensesApi {
  OfficeExpensesApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<OfficeExpenseDto>> list() async {
    return _client.getJson<List<OfficeExpenseDto>>(
      'office-expenses',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(OfficeExpenseDto.fromJson).toList();
      },
    );
  }

  Future<OfficeExpenseDto> create({
    required double amount,
    String? description,
  }) async {
    return _client.postJson<OfficeExpenseDto>(
      'office-expenses',
      {
        'amount': amount,
        'description': description,
      },
      decode: (json) => OfficeExpenseDto.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<List<OfficeExpenseReceiptDto>> listReceipts(int expenseId) async {
    return _client.getJson<List<OfficeExpenseReceiptDto>>(
      'office-expenses/$expenseId/receipts',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(OfficeExpenseReceiptDto.fromJson).toList();
      },
    );
  }
}

class OfficeExpenseFilesApiException implements Exception {
  OfficeExpenseFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class OfficeExpenseFilesApi {
  OfficeExpenseFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<void> uploadReceipt({
    required int expenseId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw OfficeExpenseFilesApiException('الملف غير متاح للرفع');
    }
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw OfficeExpenseFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('office-expenses/$expenseId/receipts');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(http.MultipartFile.fromBytes('upload', bytes, filename: file.name));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw OfficeExpenseFilesApiException(body.isEmpty ? 'فشل رفع الإيصال' : body, statusCode: streamed.statusCode);
    }
  }

  Future<(Uint8List bytes, String? contentType)> downloadReceipt(int fileId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw OfficeExpenseFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('office-expense-receipts/$fileId');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw OfficeExpenseFilesApiException('فشل تنزيل الإيصال', statusCode: res.statusCode);
    }
    return (res.bodyBytes, res.headers['content-type']);
  }
}

