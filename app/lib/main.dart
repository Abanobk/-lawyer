import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/config/tenant_build_config.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/core/theme/theme_mode_scope.dart';
import 'package:lawyer_app/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LawyerApp());
}

/// يسمح بتمرير الجداول الأفقية باللمس على الويب والموبايل (بدونها يصعب السحب على بعض المتصفحات).
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
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
            title: TenantBuildConfig.officeCode.isEmpty
                ? 'مكتب المحاماة الحديث'
                : 'مكتب المحاماة — ${TenantBuildConfig.officeCode}',
            scrollBehavior: _AppScrollBehavior(),
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
