import 'package:lawyer_app/data/api/api_client.dart';

/// أحدث إصدار أندرويد مسجّل للمكتب (من CI عبر `/internal/office-mobile-builds`).
class OfficeMobileDownloadDto {
  OfficeMobileDownloadDto({
    required this.officeCode,
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.builtAt,
    this.sha256Hex,
    this.releaseNotes,
  });

  final String officeCode;
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final DateTime builtAt;
  final String? sha256Hex;
  final String? releaseNotes;

  factory OfficeMobileDownloadDto.fromJson(Map<String, dynamic> json) {
    return OfficeMobileDownloadDto(
      officeCode: json['office_code'] as String,
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      downloadUrl: json['download_url'] as String,
      builtAt: DateTime.parse(json['built_at'] as String),
      sha256Hex: json['sha256_hex'] as String?,
      releaseNotes: json['release_notes'] as String?,
    );
  }
}

class MobileBuildApi {
  MobileBuildApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// للمستخدم المسجّل داخل المكتب (يتطلب JWT).
  Future<OfficeMobileDownloadDto?> latestForMyOffice() async {
    try {
      return await _client.getJson<OfficeMobileDownloadDto>(
        'office/mobile-download',
        decode: (json) => OfficeMobileDownloadDto.fromJson(json as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// لاستخدام تطبيق أندرويد عند فحص التحديث (بدون تسجيل دخول).
  Future<OfficeMobileDownloadDto?> latestPublic(String officeCode) async {
    final code = officeCode.trim();
    if (code.isEmpty) return null;
    try {
      return await _client.getJson<OfficeMobileDownloadDto>(
        'public/offices/$code/mobile-app',
        decode: (json) => OfficeMobileDownloadDto.fromJson(json as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
