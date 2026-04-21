/// قيم تُحقَن وقت بناء APK (white-label) عبر `--dart-define`.
///
/// مثال:
/// `flutter build apk --dart-define=OFFICE_CODE=myoffice --dart-define=API_BASE_URL=https://api.example.com/api`
class TenantBuildConfig {
  TenantBuildConfig._();

  /// رمز المكتب كما في الرابط `/o/<code>/...` — يُعرض في العنوان ويمكن استخدامه لاحقاً في مسارات الدخول.
  static const String officeCode = String.fromEnvironment('OFFICE_CODE', defaultValue: '');

  /// Web OAuth client id من Google Cloud (النوع Web application) — مطلوب لعمل `google_sign_in` على أندرويد بشكل موثوق.
  /// مرّره عند البناء: `--dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com`
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');

  static bool get isTenantApk => officeCode.trim().isNotEmpty;
}
