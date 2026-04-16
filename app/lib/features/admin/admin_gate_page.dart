import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/data/api/admin_api.dart';
import 'package:lawyer_app/data/api/auth_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';

/// مدخل السوبر أدمن (FAB من الشاشة الرئيسية). الحماية الفعلية من الـ API.
class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _authApi = AuthApi();
  final _meApi = MeApi();
  final _storage = AuthTokenStorage();

  bool _loading = false;
  bool _authed = false;

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
      final tokens = await _authApi.login(email: email, password: pass);
      await _storage.saveTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
      final me = await _meApi.me();
      if (!mounted) return;
      if (me.role != 'super_admin') {
        await _storage.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية سوبر أدمن')));
        return;
      }
      setState(() => _authed = true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('سوبر أدمن'),
        actions: [
          if (_authed)
            TextButton(
              onPressed: () async {
                await _storage.clear();
                if (!mounted) return;
                setState(() => _authed = false);
              },
              child: const Text('خروج'),
            ),
        ],
      ),
      body: ContentCanvas(
        child: Align(
          alignment: AppLayout.isWebDesktop(context) ? Alignment.center : Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _authed ? const _SuperAdminDashboard() : _LoginCard(email: _email, pass: _pass, loading: _loading, onSubmit: _submit),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.email, required this.pass, required this.loading, required this.onSubmit});

  final TextEditingController email;
  final TextEditingController pass;
  final bool loading;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تسجيل دخول سوبر أدمن', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              onSubmitted: (_) => loading ? null : onSubmit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              child: loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuperAdminDashboard extends StatefulWidget {
  const _SuperAdminDashboard();

  @override
  State<_SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<_SuperAdminDashboard> {
  final _meApi = MeApi();
  final _adminApi = AdminApi();

  late Future<MeDto> _meFuture = _meApi.me();

  final _currentPass = TextEditingController();
  final _newEmail = TextEditingController();
  final _newPass = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentPass.dispose();
    _newEmail.dispose();
    _newPass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cur = _currentPass.text;
    final email = _newEmail.text.trim();
    final pass = _newPass.text;
    if (cur.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب كلمة المرور الحالية')));
      return;
    }
    if (email.isEmpty && pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب بريد جديد أو كلمة مرور جديدة')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _adminApi.updateMyCredentials(
        currentPassword: cur,
        newEmail: email.isEmpty ? null : email,
        newPassword: pass.isEmpty ? null : pass,
      );
      if (!mounted) return;
      _currentPass.clear();
      _newEmail.clear();
      _newPass.clear();
      setState(() => _meFuture = _meApi.me());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات السوبر أدمن')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MeDto>(
      future: _meFuture,
      builder: (context, snap) {
        final email = snap.data?.email ?? '—';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('لوحة السوبر أدمن', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('الحساب الحالي: $email'),
                const SizedBox(height: 16),
                Text('تغيير البريد/كلمة المرور', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPass,
                  decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newEmail,
                  decoration: const InputDecoration(labelText: 'البريد الجديد (اختياري)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPass,
                  decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة (اختياري)'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('حفظ التغييرات'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
