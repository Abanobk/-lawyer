import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/config/tenant_build_config.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (TenantBuildConfig.isTenantApk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return;
    }
    _autoRedirectIfSignedIn();
  }

  Future<void> _autoRedirectIfSignedIn() async {
    final storage = AuthTokenStorage();
    final token = await storage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      if (mounted) setState(() => _checked = true);
      return;
    }

    // If we already know the office code, go straight to it.
    final code = (await storage.getOfficeCode())?.trim();
    if (code != null && code.isNotEmpty) {
      if (mounted) context.go('/o/$code/dashboard');
      return;
    }

    // Otherwise, resolve office from backend once, then persist.
    try {
      final office = await OfficeApi().myOffice();
      await storage.saveOfficeCode(office.code);
      if (mounted) context.go('/o/${office.code}/dashboard');
      return;
    } catch (_) {
      // If token is invalid/expired, fall back to landing choices.
      if (mounted) setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppLayout.isWebDesktop(context);

    return Scaffold(
      body: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0F2744), Color(0xFF1E3A8A)],
              ),
            ),
            child: SafeArea(
              child: !_checked
                  ? const Center(child: CircularProgressIndicator())
                  : (wide ? _WideBody() : _CompactBody()),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FloatingActionButton.small(
                heroTag: 'admin_fab',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryBlue,
                tooltip: 'دخول السوبر أدمن',
                onPressed: () => context.go('/admin'),
                child: const Icon(Icons.admin_panel_settings_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _IntroCard(),
        ),
      ),
    );
  }
}

class _WideBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'مكتب المحاماة الحديث',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 40,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'نظام SaaS متعدد المكاتب: كل مكتب برابط خاص، تجربة ٣٠ يومًا، ولوحة تحكم منفصلة عن باقي العملاء.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryBlue,
                          ),
                          onPressed: () => context.go('/signup'),
                          child: const Text('إنشاء مكتب جديد'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => context.go('/login'),
                          child: const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: Center(child: _IntroCard()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black45,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            Text(
              'ابدأ الآن',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'بعد التسجيل يصلك رابط مكتبك على شكل /o/كود-المكتب',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/signup'),
              child: const Text('تسجيل مكتب'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('لدي حساب بالفعل'),
            ),
          ],
        ),
      ),
    );
  }
}
