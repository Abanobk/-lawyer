import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

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

  String _parseErrorDetail(String body) {
    try {
      final map = jsonDecode(body);
      if (map is! Map<String, dynamic>) return 'فشل رفع الملف';
      final detail = map['detail'];
      if (detail is String) return detail;
    } catch (_) {}
    return 'فشل رفع الملف';
  }
}

