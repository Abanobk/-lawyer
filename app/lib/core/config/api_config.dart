import 'package:flutter/foundation.dart';

/// عنوان الـ API كما يظهر للعميل (بدون شرطة مزدوجة في النهاية).
/// - تطوير مباشر لـ FastAPI: `http://localhost:8000`
/// - إنتاج خلف Nginx بنفس الموقع: `/api` (يُكمّل مع نطاق الصفحة تلقائيًا على الويب)
/// - أو عنوانًا كاملًا: `https://lawyer.easytecheg.net/api`
///
/// أمثلة بناء:
/// `flutter build web --dart-define=API_BASE_URL=/api`
/// `flutter build web --dart-define=API_BASE_URL=https://lawyer.easytecheg.net/api`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static Uri uri(String path) {
    final p = path.replaceAll(RegExp(r'^/+'), '');
    var base = baseUrl.replaceAll(RegExp(r'/+$'), '');

    if (base.startsWith('http://') || base.startsWith('https://')) {
      return Uri.parse('$base/$p');
    }

    if (!base.startsWith('/')) {
      base = '/$base';
    }

    if (kIsWeb) {
      final origin = Uri.base.origin;
      final fullPath = '$base/$p'.replaceAll(RegExp(r'//+'), '/');
      return Uri.parse('$origin$fullPath');
    }

    throw UnsupportedError(
      'على Android/iOS عيّن API_BASE_URL كعنوان كامل (مثلاً https://lawyer.easytecheg.net/api)',
    );
  }
}
