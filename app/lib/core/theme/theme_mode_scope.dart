import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يحفظ اختيار المستخدم (فاتح / داكن / النظام) ويُمرَّر لـ [MaterialApp.themeMode].
class ThemeModeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  static const _prefKey = 'app_theme_mode';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_prefKey);
    _mode = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefKey,
      switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}

class ThemeModeScope extends InheritedWidget {
  const ThemeModeScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ThemeModeController controller;

  static ThemeModeController of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    assert(s != null, 'ThemeModeScope not found');
    return s!.controller;
  }

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) => oldWidget.controller != controller;
}
