import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// نظام ألوان موحّد — أزرق داكن احترافي + ألوان دلالية (نجاح/تحذير/خطر/معلومة).
abstract final class AppColors {
  // الهوية
  static const Color sidebar = Color(0xFF0F2744);
  static const Color sidebarActive = Color(0xFF1E3A5F);
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color accent = Color(0xFF2563EB);

  // الأسطح
  static const Color surfaceMuted = Color(0xFFF3F5F9);
  static const Color cardBorder = Color(0xFFE6E9F0);

  // ألوان دلالية
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // تدرّج الهوية (للهيدر/البانرات)
  static const List<Color> brandGradient = [sidebar, primaryBlue];
}

/// أنصاف أقطار موحّدة.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    brightness: Brightness.light,
    primary: AppColors.primaryBlue,
    secondary: AppColors.accent,
    error: AppColors.danger,
  ).copyWith(surface: Colors.white);
  return _buildTheme(scheme, AppColors.surfaceMuted);
}

ThemeData buildAppDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    brightness: Brightness.dark,
    primary: const Color(0xFF93B4FF),
    secondary: const Color(0xFF7CA8FF),
    error: const Color(0xFFF87171),
  );
  return _buildTheme(scheme, const Color(0xFF0E141B));
}

ThemeData _buildTheme(ColorScheme scheme, Color scaffoldBg) {
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final isDark = scheme.brightness == Brightness.dark;

  // خط Cairo العربي على كامل التطبيق.
  final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).copyWith(
    titleLarge: GoogleFonts.cairo(
      textStyle: base.textTheme.titleLarge,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: GoogleFonts.cairo(
      textStyle: base.textTheme.titleMedium,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: GoogleFonts.cairo(
      textStyle: base.textTheme.titleSmall,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: GoogleFonts.cairo(
      textStyle: base.textTheme.labelLarge,
      fontWeight: FontWeight.w600,
    ),
  );

  final cardColor = isDark ? scheme.surfaceContainerHigh : Colors.white;

  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBg,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.sidebar,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark ? scheme.surface : Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: GoogleFonts.cairo(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? scheme.outlineVariant.withValues(alpha: 0.4) : AppColors.cardBorder,
        ),
      ),
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 15),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 15),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      insetPadding: const EdgeInsets.all(16),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      surfaceTintColor: Colors.transparent,
      backgroundColor: cardColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF7F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
  );
}
