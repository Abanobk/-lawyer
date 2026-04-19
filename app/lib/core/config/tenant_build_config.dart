/// قيم تُحقَن وقت بناء APK (white-label) عبر `--dart-define`.
///
/// مثال:
/// `flutter build apk --dart-define=OFFICE_CODE=myoffice --dart-define=API_BASE_URL=https://api.example.com/api`
class TenantBuildConfig {
  TenantBuildConfig._();

  /// رمز المكتب كما في الرابط `/o/<code>/...` — يُعرض في العنوان ويمكن استخدامه لاحقاً في مسارات الدخول.
  static const String officeCode = String.fromEnvironment('OFFICE_CODE', defaultValue: '');
}
