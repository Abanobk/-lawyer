import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// يفرّق بين واجهة الويب العريضة وتخطيط الموبايل/الويب الضيق
/// حتى لا تُعرض نفس واجهة الموبايل ممتدة على الشاشة الكبيرة.
class AppLayout {
  AppLayout._();

  static Size _size(BuildContext context) => MediaQuery.sizeOf(context);

  /// ويب بعرض هاتف/عرض ضيق — مساحات أصغر وبطاقات بدل الجداول العريضة حيث يُستخدم [AdaptiveDataTable].
  static bool isWebCompact(BuildContext context) => kIsWeb && _size(context).width < 900;

  /// هاتف عمودي أو عرض ضيق جداً (بروز أسطر، تقليل الهوامش).
  static bool isVeryNarrow(BuildContext context) => _size(context).width < 400;

  /// ويب + عرض كافٍ **و** أقل بعد للشاشة كافٍ: يتجنّب وضع «الشريط الجانبي» على هاتف بالعرض فقط
  /// (مثلاً ~900×400) حيث يبقى المحتوى مضغوطاً.
  static bool isWebDesktop(BuildContext context) {
    if (!kIsWeb) return false;
    final sz = _size(context);
    final shortest = sz.shortestSide;
    return sz.width >= 900 && shortest >= 480;
  }

  /// ويب عريض جداً: نحدّ المحتوى بعرض أقصى ونوسّطه لقراءة أوضح.
  static bool useCenteredContentCanvas(BuildContext context) {
    final w = _size(context).width;
    return kIsWeb && w >= 1100;
  }

  static double contentMaxWidth(BuildContext context) {
    if (useCenteredContentCanvas(context)) return 1320;
    return double.infinity;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    if (isWebDesktop(context)) {
      return const EdgeInsets.fromLTRB(32, 18, 32, 24);
    }
    if (isVeryNarrow(context)) {
      return const EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 16);
  }
}
