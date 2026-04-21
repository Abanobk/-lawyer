import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/core/config/tenant_build_config.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/data/api/auth_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _authApi = AuthApi();
  final _officeApi = OfficeApi();
  final _storage = AuthTokenStorage();

  bool _loading = false;
  bool _showPass = false;
  bool _prefilled = false;
  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: TenantBuildConfig.googleWebClientId.trim().isEmpty
        ? null
        : TenantBuildConfig.googleWebClientId.trim(),
  );

  @override
  void initState() {
    super.initState();
    _prefillAndAutoRedirect();
  }

  Future<void> _prefillAndAutoRedirect() async {
    final tenant = TenantBuildConfig.officeCode.trim();
    // If already signed in, go directly to the office dashboard.
    final token = await _storage.getAccessToken();
    final code = await _storage.getOfficeCode();
    if (!mounted) return;
    if (token != null && token.trim().isNotEmpty) {
      if (tenant.isNotEmpty) {
        await _storage.saveOfficeCode(tenant);
        if (mounted) context.go('/o/$tenant/dashboard');
        return;
      }
      if (code != null && code.trim().isNotEmpty) {
        context.go('/o/${code.trim()}/dashboard');
        return;
      }
    }

    // Prefill last used email for convenience.
    final lastEmail = await _storage.getLastEmail();
    if (!mounted) return;
    if (!_prefilled && lastEmail != null && lastEmail.isNotEmpty) {
      _email.text = lastEmail;
      _prefilled = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || !email.contains('@') || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البريد وكلمة المرور')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _storage.saveLastEmail(email);
      final tokens = await _authApi.login(email: email, password: pass);

      // Temporarily save tokens to call /office (needs Authorization header).
      await _storage.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        officeCode: 'pending',
      );

      final office = await _officeApi.myOffice();
      final tenantCode = TenantBuildConfig.officeCode.trim();
      if (tenantCode.isNotEmpty && office.code != tenantCode) {
        await _storage.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذا الحساب لا يخص مكتب هذا التطبيق.')),
        );
        return;
      }
      await _storage.saveSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        officeCode: office.code,
      );

      if (!mounted) return;
      context.go('/o/${office.code}/dashboard');
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickGoogleEmail() async {
    if (_loading) return;
    try {
      final account = await _google.signIn();
      if (account == null) return;
      if (!mounted) return;
      _email.text = account.email;
      await _storage.saveLastEmail(account.email);
      if (!mounted) return;
      FocusScope.of(context).nextFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اختيار البريد من Google. أكمل كلمة المرور.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل Google على هذا الجهاز: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('تسجيل الدخول'),
      ),
      body: ContentCanvas(
        child: Align(
          alignment: AppLayout.isWebDesktop(context) ? Alignment.center : Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('مرحبًا بعودتك', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'سجّل الدخول بحسابك، وسيتم تحويلك تلقائيًا إلى رابط مكتبك.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      Text(
                        'الخادم (تصحيح): ${ApiConfig.baseUrl}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pickGoogleEmail,
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('اختيار البريد من Google'),
                    ),
                    if (!kIsWeb && TenantBuildConfig.googleWebClientId.trim().isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'لتفعيل Google على أندرويد: أضف Web Client ID من Google Cloud ومرّره عند البناء: --dart-define=GOOGLE_WEB_CLIENT_ID=…',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pass,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        suffixIcon: IconButton(
                          tooltip: _showPass ? 'إخفاء' : 'إظهار',
                          onPressed: _loading ? null : () => setState(() => _showPass = !_showPass),
                          icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      obscureText: !_showPass,
                      onSubmitted: (_) => _loading ? null : _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('دخول'),
                    ),
                    if (!TenantBuildConfig.isTenantApk)
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('ليس لديك مكتب؟ أنشئ حسابًا'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
