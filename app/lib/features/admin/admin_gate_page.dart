import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/data/api/admin_api.dart';
import 'package:lawyer_app/data/api/auth_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';

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
  void initState() {
    super.initState();
    _resumeIfTokenExists();
  }

  Future<void> _resumeIfTokenExists() async {
    final access = await _storage.getAccessToken();
    if (access == null || access.isEmpty) return;
    try {
      final me = await _meApi.me();
      if (!mounted) return;
      if (me.role == 'super_admin') {
        setState(() => _authed = true);
      } else {
        await _storage.clear();
      }
    } catch (_) {
      // token invalid/expired
      await _storage.clear();
    }
    if (!mounted) return;
    setState(() {}); // refresh UI
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
            _PasswordField(
              controller: pass,
              labelText: 'كلمة المرور',
              enabled: !loading,
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

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.labelText,
    required this.enabled,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          tooltip: _show ? 'إخفاء' : 'إظهار',
          onPressed: widget.enabled ? () => setState(() => _show = !_show) : null,
          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      enabled: widget.enabled,
      obscureText: !_show,
      onSubmitted: widget.onSubmitted,
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
  final _proofFilesApi = AdminPaymentProofFilesApi();

  late Future<MeDto> _meFuture = _meApi.me();
  late final Future<List<AdminOfficeDto>> _officesFuture = _adminApi.listOffices();
  late Future<List<AdminPlanDto>> _plansFuture = _adminApi.listPlans();
  late Future<List<AdminPaymentProofDto>> _proofsFuture = _adminApi.listPaymentProofs(status: 'pending');

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
    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 650.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'المكاتب'),
                  Tab(text: 'الباقات'),
                  Tab(text: 'التحويلات'),
                  Tab(text: 'إعدادات'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: (maxH - 60).clamp(420.0, 900.0),
                child: TabBarView(
                  children: [
                    _OfficesTab(future: _officesFuture, adminApi: _adminApi),
                    _PlansTab(
                      future: _plansFuture,
                      adminApi: _adminApi,
                      onRefresh: () => setState(() => _plansFuture = _adminApi.listPlans()),
                    ),
                    _ProofsTab(
                      future: _proofsFuture,
                      adminApi: _adminApi,
                      filesApi: _proofFilesApi,
                      onRefresh: (status) => setState(() => _proofsFuture = _adminApi.listPaymentProofs(status: status)),
                    ),
                    _SettingsTab(
                      meFuture: _meFuture,
                      currentPass: _currentPass,
                      newEmail: _newEmail,
                      newPass: _newPass,
                      saving: _saving,
                      onSave: _save,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlansTab extends StatefulWidget {
  const _PlansTab({required this.future, required this.adminApi, required this.onRefresh});
  final Future<List<AdminPlanDto>> future;
  final AdminApi adminApi;
  final VoidCallback onRefresh;

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController();
  final _link = TextEditingController();
  final _packageKey = TextEditingController();
  final _maxUsers = TextEditingController();
  final _price6 = TextEditingController();
  final _days6 = TextEditingController();
  final _link6 = TextEditingController();
  final _selectedPermKeys = <String>[];
  bool _saving = false;
  bool _uploadingPromo = false;
  final _promoFilesApi = AdminPlanPromoFilesApi();
  PlatformFile? _packagePromoFile;
  late Future<List<PermissionCatalogItemDto>> _permsFuture;

  @override
  void initState() {
    super.initState();
    _maxUsers.text = '3';
    _days.text = '90';
    _days6.text = '180';
    _packageKey.text = '';
    _permsFuture = widget.adminApi.permissionsCatalog();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    _link.dispose();
    _packageKey.dispose();
    _maxUsers.dispose();
    _price6.dispose();
    _days6.dispose();
    _link6.dispose();
    super.dispose();
  }

  Future<void> _pickPackagePromo() async {
    final res = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      type: FileType.image,
    );
    final file = (res?.files.isNotEmpty ?? false) ? res!.files.first : null;
    if (file == null) return;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير متاح للرفع')));
      return;
    }
    setState(() => _packagePromoFile = file);
  }

  Future<void> _createPackageWithOptions() async {
    final packageName = _name.text.trim();
    final packageKeyVal = _packageKey.text.trim().isEmpty ? packageName : _packageKey.text.trim();
    final maxUsersVal = int.tryParse(_maxUsers.text.trim());

    final price3 = double.tryParse(_price.text.trim());
    final days3 = int.tryParse(_days.text.trim());
    final link3 = _link.text.trim();

    final price6 = double.tryParse(_price6.text.trim());
    final days6 = int.tryParse(_days6.text.trim());
    final link6 = _link6.text.trim();

    if (packageName.length < 2 || maxUsersVal == null || maxUsersVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم الباقة وعدد المستخدمين بشكل صحيح')));
      return;
    }
    if (price3 == null || price3 <= 0 || days3 == null || days3 <= 0 || link3.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل خيار 3 شهور (سعر/مدة/رابط) بشكل صحيح')));
      return;
    }
    if (price6 == null || price6 <= 0 || days6 == null || days6 <= 0 || link6.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل خيار 6 شهور (سعر/مدة/رابط) بشكل صحيح')));
      return;
    }

    final allowedPermKeys = _selectedPermKeys.isEmpty ? null : List<String>.from(_selectedPermKeys);

    setState(() => _saving = true);
    try {
      final plans = <AdminPlanDto>[];
      final name3 = '$packageName — $days3 يوم';
      final name6 = '$packageName — $days6 يوم';

      final p3 = await widget.adminApi.createPlan(
        name: name3,
        priceCents: (price3 * 100).round(),
        durationDays: days3,
        instapayLink: link3,
        packageKey: packageKeyVal,
        packageName: packageName,
        maxUsers: maxUsersVal,
        allowedPermKeys: allowedPermKeys,
      );
      plans.add(p3);

      final p6 = await widget.adminApi.createPlan(
        name: name6,
        priceCents: (price6 * 100).round(),
        durationDays: days6,
        instapayLink: link6,
        packageKey: packageKeyVal,
        packageName: packageName,
        maxUsers: maxUsersVal,
        allowedPermKeys: allowedPermKeys,
      );
      plans.add(p6);

      if (_packagePromoFile != null) {
        for (final p in plans) {
          await _promoFilesApi.uploadPromoImage(planId: p.id, file: _packagePromoFile!);
        }
      }

      if (!mounted) return;
      _name.clear();
      _packageKey.clear();
      _maxUsers.text = '3';
      _price.clear();
      _days.text = '90';
      _link.clear();
      _price6.clear();
      _days6.text = '180';
      _link6.clear();
      _selectedPermKeys.clear();
      _packagePromoFile = null;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الباقة + خيارات الدفع')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إنشاء الباقة: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(AdminPlanDto p) async {
    final name = TextEditingController(text: p.name);
    final price = TextEditingController(text: (p.priceCents / 100).toStringAsFixed(2));
    final days = TextEditingController(text: '${p.durationDays}');
    final link = TextEditingController(text: p.instapayLink ?? '');
    bool? active = p.isActive;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تعديل باقة #${p.id}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 12),
                TextField(controller: price, decoration: const InputDecoration(labelText: 'السعر (جنيه)'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: days, decoration: const InputDecoration(labelText: 'المدة (أيام)'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: link, decoration: const InputDecoration(labelText: 'رابط إنستاباي')),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (context, setInner) => SwitchListTile(
                    title: const Text('مفعّلة'),
                    value: active ?? true,
                    onChanged: (v) => setInner(() => active = v),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      );
      if (ok != true) return;
      final priceVal = double.tryParse(price.text.trim());
      final daysVal = int.tryParse(days.text.trim());
      if (!mounted) return;
      await widget.adminApi.updatePlan(
        p.id,
        name: name.text.trim(),
        priceCents: priceVal == null ? null : (priceVal * 100).round(),
        durationDays: daysVal,
        instapayLink: link.text.trim().isEmpty ? '' : link.text.trim(),
        isActive: active,
      );
      widget.onRefresh();
    } finally {
      name.dispose();
      price.dispose();
      days.dispose();
      link.dispose();
    }
  }

  Future<void> _uploadPromo(AdminPlanDto p) async {
    if (_uploadingPromo) return;
    final res = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      type: FileType.image,
    );
    final file = (res?.files.isNotEmpty ?? false) ? res!.files.first : null;
    if (file == null) return;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير متاح للرفع')));
      return;
    }

    setState(() => _uploadingPromo = true);
    try {
      await _promoFilesApi.uploadPromoImage(planId: p.id, file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع صورة الباقة')));
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الصورة: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPromo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('الباقات', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(onPressed: widget.onRefresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('إضافة باقة (مستخدمين + موديولات + 3/6 شهور)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _packageKey,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'package_key (اختياري للتجميع)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'اسم الباقة (يظهر للمستاجر)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxUsers,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'عدد المستخدمين (يشمل office_owner)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<PermissionCatalogItemDto>>(
                      future: _permsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        if (snap.hasError) return Text('تعذر تحميل صلاحيات: ${snap.error}');
                        final items = snap.data ?? const <PermissionCatalogItemDto>[];
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: items.map((it) {
                            final selected = _selectedPermKeys.contains(it.key);
                            return FilterChip(
                              label: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              selected: selected,
                              onSelected: _saving
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v) {
                                          _selectedPermKeys.add(it.key);
                                        } else {
                                          _selectedPermKeys.remove(it.key);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('خيارات الدفع', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _days,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: '3 شهور (أيام)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _price,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'سعر 3 شهور'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _link,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'رابط إنستاباي (3 شهور)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _days6,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: '6 شهور (أيام)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _price6,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'سعر 6 شهور'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _link6,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'رابط إنستاباي (6 شهور)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _packagePromoFile?.name == null ? 'بدون صورة دعاية' : 'تم اختيار صورة: ${_packagePromoFile!.name}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: !_saving ? _pickPackagePromo : null,
                          child: const Text('اختيار صورة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _createPackageWithOptions,
                      child: _saving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ الباقة + خياراتها'),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AdminPlanDto>>(
                future: widget.future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('تعذر تحميل الباقات: ${snap.error}'));
                  final plans = snap.data ?? const <AdminPlanDto>[];
                  if (plans.isEmpty) return const Center(child: Text('لا توجد باقات'));
                  return ListView.separated(
                    itemCount: plans.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = plans[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(
                          'السعر: ${(p.priceCents / 100).toStringAsFixed(2)} — المدة: ${p.durationDays} يوم'
                          ' — حتى: ${p.maxUsers ?? "—"} مستخدم'
                          ' — صلاحيات: ${p.allowedPermKeys?.length ?? "—"}'
                          ' — ${p.isActive ? "مفعّلة" : "معطّلة"}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(onPressed: () => _edit(p), tooltip: 'تعديل', icon: const Icon(Icons.edit)),
                            IconButton(
                              onPressed: () => _uploadPromo(p),
                              tooltip: 'رفع صورة الدعاية',
                              icon: const Icon(Icons.image_outlined),
                            ),
                            IconButton(
                              onPressed: () async {
                                await widget.adminApi.deletePlan(p.id);
                                widget.onRefresh();
                              },
                              tooltip: 'تعطيل',
                              icon: const Icon(Icons.block),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofsTab extends StatefulWidget {
  const _ProofsTab({required this.future, required this.adminApi, required this.filesApi, required this.onRefresh});
  final Future<List<AdminPaymentProofDto>> future;
  final AdminApi adminApi;
  final AdminPaymentProofFilesApi filesApi;
  final void Function(String status) onRefresh;

  @override
  State<_ProofsTab> createState() => _ProofsTabState();
}

class _ProofsTabState extends State<_ProofsTab> {
  String _status = 'pending';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('تحويلات إنستاباي', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                    DropdownMenuItem(value: 'approved', child: Text('تمت الموافقة')),
                    DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _status = v);
                          widget.onRefresh(v);
                        },
                ),
                IconButton(
                  onPressed: _busy ? null : () => widget.onRefresh(_status),
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AdminPaymentProofDto>>(
                future: widget.future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('تعذر تحميل التحويلات: ${snap.error}'));
                  final proofs = snap.data ?? const <AdminPaymentProofDto>[];
                  if (proofs.isEmpty) return const Center(child: Text('لا توجد تحويلات'));
                  return ListView.separated(
                    itemCount: proofs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = proofs[i];
                      return ListTile(
                        title: Text('إثبات #${p.id} — مكتب #${p.officeId}'),
                        subtitle: Text('الحالة: ${p.status} — خطة: ${p.planId ?? "—"}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openProof(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProof(AdminPaymentProofDto p) async {
    setState(() => _busy = true);
    try {
      final (bytes, contentType) = await widget.filesApi.downloadProof(p.id);
      if (!mounted) return;
      final decision = TextEditingController(text: p.decisionNotes ?? '');
      final isPdf = (contentType ?? '').contains('pdf');
      final canReview = p.status == 'pending';
      final res = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('إثبات #${p.id}'),
          content: SizedBox(
            width: 900,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPdf)
                  const Text('ملف PDF (المعاينة داخل التطبيق غير مدعومة).')
                else
                  Image.memory(bytes, fit: BoxFit.contain),
                const SizedBox(height: 12),
                TextField(
                  controller: decision,
                  decoration: const InputDecoration(labelText: 'ملاحظات القرار (اختياري)'),
                  minLines: 2,
                  maxLines: 4,
                  enabled: canReview,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'close'), child: const Text('إغلاق')),
            if (canReview) ...[
              TextButton(onPressed: () => Navigator.pop(context, 'reject:${decision.text}'), child: const Text('رفض')),
              FilledButton(onPressed: () => Navigator.pop(context, 'approve:${decision.text}'), child: const Text('موافقة')),
            ],
          ],
        ),
      );
      decision.dispose();
      if (res == null || res == 'close') return;
      if (res.startsWith('approve:')) {
        final notes = res.substring('approve:'.length).trim();
        await widget.adminApi.approvePaymentProof(p.id, decisionNotes: notes.isEmpty ? null : notes);
      } else if (res.startsWith('reject:')) {
        final notes = res.substring('reject:'.length).trim();
        await widget.adminApi.rejectPaymentProof(p.id, decisionNotes: notes.isEmpty ? null : notes);
      }
      widget.onRefresh(_status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الإثبات: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _OfficesTab extends StatefulWidget {
  const _OfficesTab({required this.future, required this.adminApi});
  final Future<List<AdminOfficeDto>> future;
  final AdminApi adminApi;

  @override
  State<_OfficesTab> createState() => _OfficesTabState();
}

class _OfficesTabState extends State<_OfficesTab> {
  int? _selectedOfficeId;
  AdminSubscriptionDto? _sub;
  bool _loading = false;
  bool _showAllOffices = false;
  late Future<AdminTrialAnalyticsDto> _trialAnalyticsFuture;

  @override
  void initState() {
    super.initState();
    _trialAnalyticsFuture = widget.adminApi.trialAnalytics(days: 30);
  }

  Future<void> _loadSub(int officeId) async {
    setState(() {
      _selectedOfficeId = officeId;
      _loading = true;
      _sub = null;
    });
    try {
      final s = await widget.adminApi.getSubscription(officeId);
      if (!mounted) return;
      setState(() => _sub = s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<AdminOfficeDto>>(
          future: widget.future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('تعذر تحميل المكاتب: ${snap.error}'));
            }
            final offices = snap.data ?? const <AdminOfficeDto>[];
            if (offices.isEmpty) return const Center(child: Text('لا يوجد مكاتب بعد'));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('عرض الاشتراكات:', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    DropdownButton<bool>(
                      value: _showAllOffices,
                      items: const [
                        DropdownMenuItem(value: false, child: Text('اختيار مكتب واحد')),
                        DropdownMenuItem(value: true, child: Text('جميع المستاجرين')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _showAllOffices = v;
                          _selectedOfficeId = null;
                          _sub = null;
                          _loading = false;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _showAllOffices
                      ? FutureBuilder<List<AdminSubscriptionDto?>>(
                          future: Future.wait(
                            offices.map((o) async {
                              try {
                                return await widget.adminApi.getSubscription(o.id);
                              } catch (_) {
                                return null;
                              }
                            }),
                          ),
                          builder: (context, snapSubs) {
                            if (snapSubs.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            if (snapSubs.hasError) return Center(child: Text('تعذر تحميل الاشتراكات: ${snapSubs.error}'));
                            final subs = (snapSubs.data ?? const <AdminSubscriptionDto?>[]).whereType<AdminSubscriptionDto>().toList();
                            if (subs.isEmpty) return const Center(child: Text('لا توجد اشتراكات'));
                            return ListView.separated(
                              itemCount: subs.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final s = subs[i];
                                final office = (() {
                                  for (final o in offices) {
                                    if (o.id == s.officeId) return o;
                                  }
                                  return null;
                                })();
                                return ListTile(
                                  title: Text(office?.name ?? 'مكتب #${s.officeId}'),
                                  subtitle: Text(
                                    'الحالة: ${s.status} — ${s.endAt.toLocal()}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                );
                              },
                            );
                          },
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ListView(
                                children: offices
                                    .map(
                                      (o) => ListTile(
                                        title: Text(o.name),
                                        subtitle: Text('كود: ${o.code} — ${o.status}'),
                                        selected: _selectedOfficeId == o.id,
                                        onTap: () => _loadSub(o.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _selectedOfficeId == null
                          ? FutureBuilder<AdminTrialAnalyticsDto>(
                              future: _trialAnalyticsFuture,
                              builder: (context, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snap.hasError) {
                                  return Center(child: Text('تعذر تحميل إحصاءات التجربة: ${snap.error}'));
                                }
                                final data = snap.data;
                                if (data == null || data.offices.isEmpty) {
                                  return const Center(child: Text('لا توجد مكاتب تجريبية خلال آخر 30 يوم'));
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'مكاتب التجربة (آخر ${data.days} يوم): ${data.totalTrialOffices}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 240,
                                      child: ListView.separated(
                                        itemCount: data.offices.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemBuilder: (context, i) {
                                          final o = data.offices[i];
                                          return ListTile(
                                            dense: true,
                                            title: Text(o.officeName),
                                            subtitle: Text(
                                              'المستخدمين الآن: ${o.activeUsersCount} — ينتهي: ${o.trialEndAt.toLocal()}',
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                                      : (_loading
                                          ? const Center(child: CircularProgressIndicator())
                                          : (_sub == null
                                              ? const Center(child: Text('لا توجد بيانات اشتراك'))
                                              : Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    Text('حالة الاشتراك: ${_sub!.status}', style: Theme.of(context).textTheme.titleMedium),
                                                    const SizedBox(height: 8),
                                                    Text('بداية: ${_sub!.startAt.toLocal()}'),
                                                    Text('نهاية: ${_sub!.endAt.toLocal()}'),
                                                    if ((_sub!.notes ?? '').isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text('ملاحظات: ${_sub!.notes}'),
                                                    ],
                                                  ],
                                                ))),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.meFuture,
    required this.currentPass,
    required this.newEmail,
    required this.newPass,
    required this.saving,
    required this.onSave,
  });

  final Future<MeDto> meFuture;
  final TextEditingController currentPass;
  final TextEditingController newEmail;
  final TextEditingController newPass;
  final bool saving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<MeDto>(
          future: meFuture,
          builder: (context, snap) {
            final email = snap.data?.email ?? '—';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الحساب الحالي: $email'),
                const SizedBox(height: 16),
                Text('تغيير البريد/كلمة المرور', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: currentPass,
                  labelText: 'كلمة المرور الحالية',
                  enabled: !saving,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newEmail,
                  decoration: const InputDecoration(labelText: 'البريد الجديد (اختياري)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: newPass,
                  labelText: 'كلمة المرور الجديدة (اختياري)',
                  enabled: !saving,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('حفظ التغييرات'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
