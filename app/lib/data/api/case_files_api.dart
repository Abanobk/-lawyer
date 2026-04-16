import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class CaseFileDto {
  CaseFileDto({
    required this.id,
    required this.caseId,
    required this.originalName,
    this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  final int id;
  final int caseId;
  final String originalName;
  final String? contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  factory CaseFileDto.fromJson(Map<String, dynamic> json) {
    return CaseFileDto(
      id: json['id'] as int,
      caseId: json['case_id'] as int,
      originalName: json['original_name'] as String,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class CaseFilesApiException implements Exception {
  CaseFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class CaseFilesApi {
  CaseFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<void> upload({
    required int caseId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw CaseFilesApiException('الملف غير متاح للرفع (جرّب اختيار الملف مرة أخرى)');
    }

    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CaseFilesApiException('سجّل الدخول أولاً');
    }

    final uri = ApiConfig.uri('cases/$caseId/files');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'upload',
        bytes,
        filename: file.name,
      ),
    );

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw CaseFilesApiException(_parseErrorDetail(body), statusCode: streamed.statusCode);
    }
  }

  Future<List<CaseFileDto>> list({required int caseId}) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CaseFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('cases/$caseId/files');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CaseFilesApiException(_parseErrorDetail(body), statusCode: res.statusCode);
    }
    final list = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
    return list.map(CaseFileDto.fromJson).toList();
  }

  Future<void> delete({required int fileId}) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CaseFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('case-files/$fileId');
    final res = await _client.delete(uri, headers: {'Authorization': 'Bearer $token'});
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CaseFilesApiException(_parseErrorDetail(body), statusCode: res.statusCode);
    }
  }

  Future<(Uint8List bytes, String filename, String contentType)> download({required int fileId}) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw CaseFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('case-files/$fileId');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw CaseFilesApiException(_parseErrorDetail(utf8.decode(res.bodyBytes)), statusCode: res.statusCode);
    }
    final ct = res.headers['content-type'] ?? 'application/octet-stream';
    final cd = res.headers['content-disposition'] ?? '';
    final name = _filenameFromContentDisposition(cd) ?? 'file';
    return (res.bodyBytes, name, ct);
  }

  String? _filenameFromContentDisposition(String cd) {
    // Content-Disposition: attachment; filename="x.pdf"
    final m = RegExp(r'filename=\"?([^\";]+)\"?').firstMatch(cd);
    return m?.group(1);
  }

  String _parseErrorDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return 'فشل رفع الملف';
      final detail = map['detail'];
      if (detail is String) return detail;
    } catch (_) {}
    if (kDebugMode) return body;
    return 'فشل الطلب';
  }
}

