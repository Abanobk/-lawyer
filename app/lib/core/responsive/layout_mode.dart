import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// يفرّق بين واجهة الويب العريضة وتخطيط الموبايل/الويب الضيق
/// حتى لا تُعرض نفس واجهة الموبايل ممتدة على الشاشة الكبيرة.
class AppLayout {
  AppLayout._();

  /// ويب + عرض كافٍ: شريط جانبي ثابت ومساحة محتوى واسعة.
  static bool isWebDesktop(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return kIsWeb && w >= 900;
  }

  /// ويب عريض جداً: نحدّ المحتوى بعرض أقصى ونوسّطه لقراءة أوضح.
  static bool useCenteredContentCanvas(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return kIsWeb && w >= 1100;
  }

  static double contentMaxWidth(BuildContext context) {
    if (useCenteredContentCanvas(context)) return 1320;
    return double.infinity;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (isWebDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 28);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
  }
}
