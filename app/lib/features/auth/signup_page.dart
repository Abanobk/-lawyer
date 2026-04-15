import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/core/config/api_config.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/data/api/auth_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _officeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = AuthApi();
  final _storage = AuthTokenStorage();

  bool _loading = false;

  @override
  void dispose() {
    _officeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final result = await _api.signup(
        officeName: _officeCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;

      await _storage.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        officeCode: result.officeCode,
      );

      await _showSuccessDialog(result);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ في الشبكة. تحقق من عنوان الـ API والاتصال.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showSuccessDialog(SignupResult result) async {
    final trialFmt = DateFormat.yMMMd('ar').add_Hm().format(result.trialEndAt.toLocal());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تم إنشاء المكتب'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('انتهاء التجربة: $trialFmt'),
                const SizedBox(height: 12),
                const Text('رابط المكتب (احفظه أو شاركه):'),
                const SizedBox(height: 8),
                SelectionArea(
                  child: Text(
                    result.officeLink,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: result.officeLink));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الرابط')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ الرابط'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/o/${result.officeCode}/dashboard');
              },
              child: const Text('دخول لوحة المكتب'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('تسجيل مكتب جديد'),
      ),
      body: ContentCanvas(
        child: Align(
          alignment: AppLayout.isWebDesktop(context)
              ? Alignment.center
              : Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'بيانات المكتب',
                        style: Theme.of(context).textTheme.headlineSmall,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _officeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المكتب / المؤسسة',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.length < 2) return 'أدخل اسمًا لا يقل عن حرفين';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'أدخل البريد';
                          if (!t.contains('@')) return 'صيغة البريد غير صحيحة';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                        ),
                        obscureText: true,
                        validator: (v) {
                          final t = v ?? '';
                          if (t.length < 8) return 'ثمانية أحرف على الأقل (مطابقة للخادم)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('إنشاء الحساب والحصول على الرابط'),
                      ),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text('لديك حساب؟ سجّل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
