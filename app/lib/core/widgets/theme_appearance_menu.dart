import 'package:flutter/material.dart';
import 'package:lawyer_app/core/theme/theme_mode_scope.dart';

/// قائمة اختيار المظهر: تلقائي / فاتح / داكن.
class ThemeAppearanceMenuButton extends StatelessWidget {
  const ThemeAppearanceMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<ThemeMode>(
      tooltip: 'المظهر',
      onSelected: (m) => ThemeModeScope.of(context).setMode(m),
      itemBuilder: (context) => const [
        PopupMenuItem(value: ThemeMode.system, child: Text('تلقائي (حسب النظام)')),
        PopupMenuItem(value: ThemeMode.light, child: Text('فاتح')),
        PopupMenuItem(value: ThemeMode.dark, child: Text('داكن')),
      ],
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
        child: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      ),
    );
  }
}
