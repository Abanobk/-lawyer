import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/core/theme/theme_mode_scope.dart';
import 'package:lawyer_app/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LawyerApp());
}

class LawyerApp extends StatefulWidget {
  const LawyerApp({super.key});

  @override
  State<LawyerApp> createState() => _LawyerAppState();
}

class _LawyerAppState extends State<LawyerApp> {
  late final GoRouter _router = createAppRouter();
  final ThemeModeController _theme = ThemeModeController();

  @override
  void initState() {
    super.initState();
    _theme.load();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeModeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'مكتب المحاماة الحديث',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            darkTheme: buildAppDarkTheme(),
            themeMode: _theme.mode,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
