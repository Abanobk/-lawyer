import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class PaymentProofDto {
  PaymentProofDto({
    required this.id,
    required this.officeId,
    required this.imagePath,
    required this.status,
    required this.uploadedAt,
    this.planId,
    this.notes,
    this.amountSnapshotCents,
    this.instapayLinkSnapshot,
    this.referenceCode,
    this.reviewedByUserId,
    this.reviewedAt,
    this.decisionNotes,
  });

  final int id;
  final int officeId;
  final String imagePath;
  final String status;
  final int? planId;
  final String? notes;
  final int? amountSnapshotCents;
  final String? instapayLinkSnapshot;
  final String? referenceCode;
  final int? reviewedByUserId;
  final DateTime? reviewedAt;
  final String? decisionNotes;
  final DateTime uploadedAt;

  factory PaymentProofDto.fromJson(Map<String, dynamic> json) {
    return PaymentProofDto(
      id: json['id'] as int,
      officeId: json['office_id'] as int,
      imagePath: json['image_path'] as String,
      planId: json['plan_id'] as int?,
      status: (json['status'] as String?) ?? 'pending',
      notes: json['notes'] as String?,
      amountSnapshotCents: json['amount_snapshot_cents'] as int?,
      instapayLinkSnapshot: json['instapay_link_snapshot'] as String?,
      referenceCode: json['reference_code'] as String?,
      reviewedByUserId: json['reviewed_by_user_id'] as int?,
      reviewedAt: json['reviewed_at'] == null ? null : DateTime.parse(json['reviewed_at'] as String),
      decisionNotes: json['decision_notes'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class SubscriptionApi {
  SubscriptionApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<PaymentProofDto>> listPaymentProofs() async {
    return _client.getJson<List<PaymentProofDto>>(
      'subscription/payment-proofs',
      decode: (json) {
        final list = (json as List).cast<Map<String, dynamic>>();
        return list.map(PaymentProofDto.fromJson).toList();
      },
    );
  }
}

class SubscriptionFilesApiException implements Exception {
  SubscriptionFilesApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class SubscriptionFilesApi {
  SubscriptionFilesApi({http.Client? client, AuthTokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokens = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokens;

  Future<void> uploadPaymentProof({
    required int planId,
    required PlatformFile file,
    String? referenceCode,
    String? notes,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw SubscriptionFilesApiException('الملف غير متاح للرفع');
    }
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw SubscriptionFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('subscription/payment-proofs');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['plan_id'] = '$planId';
    if ((referenceCode ?? '').trim().isNotEmpty) req.fields['reference_code'] = referenceCode!.trim();
    if ((notes ?? '').trim().isNotEmpty) req.fields['notes'] = notes!.trim();
    req.files.add(http.MultipartFile.fromBytes('upload', bytes, filename: file.name));

    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw SubscriptionFilesApiException(body.isEmpty ? 'فشل رفع إثبات التحويل' : body, statusCode: streamed.statusCode);
    }
  }

  Future<(Uint8List bytes, String? contentType)> downloadPaymentProof(int proofId) async {
    final token = await _tokens.getAccessToken();
    if (token == null || token.isEmpty) {
      throw SubscriptionFilesApiException('سجّل الدخول أولاً');
    }
    final uri = ApiConfig.uri('subscription/payment-proofs/$proofId');
    final res = await _client.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SubscriptionFilesApiException('فشل تنزيل صورة التحويل', statusCode: res.statusCode);
    }
    return (res.bodyBytes, res.headers['content-type']);
  }
}

