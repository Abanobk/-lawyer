import 'package:flutter/material.dart';
import 'package:lawyer_app/core/constants/plan_perm_labels.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _officeApi = OfficeApi();
  final _permApi = PermissionsApi();
  final _meApi = MeApi();

  late Future<_EmployeesData> _future = _load();

  Future<_EmployeesData> _load() async {
    final results = await Future.wait([
      _officeApi.users(),
      _permApi.catalog(),
      _meApi.me(),
    ]);
    return _EmployeesData(
      users: results[0] as List<OfficeUserDto>,
      catalog: results[1] as List<PermissionCatalogItemDto>,
      me: results[2] as MeDto,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createEmployee() async {
    final data = await showDialog<_CreateEmployeeResult>(
      context: context,
      builder: (context) => const _CreateEmployeeDialog(),
    );
    if (data == null) return;
    try {
      if (!mounted) return;
      await _officeApi.createUser(fullName: data.fullName, email: data.email, password: data.password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الموظف')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _disableUser(OfficeUserDto u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل المستخدم'),
        content: Text('تأكيد تعطيل المستخدم: ${u.fullName ?? u.email}\nلن يستطيع تسجيل الدخول بعد الآن.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('تعطيل')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _officeApi.disableUser(u.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل المستخدم')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editStaffName(OfficeUserDto user) async {
    final ctrl = TextEditingController(text: user.fullName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل الاسم — ${user.email}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'الاسم كما يظهر في البرنامج',
            hintText: 'مثال: أحمد محمد',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسمًا واضحًا')));
                return;
              }
              Navigator.pop(context, t);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    try {
      await _officeApi.patchUserFullName(userId: user.id, fullName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editPermissions(_EmployeesData data, OfficeUserDto user) async {
    final current = await _permApi.getForUser(user.id);
    if (!mounted) return;
    final catalogKeys = data.catalog.map((e) => e.key).toSet();
    final updated = await showDialog<List<String>>(
      context: context,
      builder: (context) => _PermissionsDialog(
        title: 'صلاحيات: ${user.fullName ?? user.email}',
        catalog: data.catalog,
        initial: current.permissions,
        catalogKeys: catalogKeys,
      ),
    );
    if (updated == null) return;
    try {
      await _permApi.setForUser(user.id, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصلاحيات')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'office_owner':
        return 'مالك المكتب';
      case 'staff':
        return 'موظف';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primaryContainer.withValues(alpha: 0.35), scheme.surface],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_2_outlined, color: scheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموظفين والصلاحيات',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'حدّد اسم كل موظف وصلاحياته. صلاحية «البيانات المالية الحساسة» تُمنح يدويًا لمن يثق به المالك — بدونها يقتصر الموظف على الصندوق والعُهد دون رؤية أتعاب الموكلين والملخصات.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _createEmployee,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('إضافة موظف'),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<_EmployeesData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('تعذر تحميل الموظفين: ${snap.error}'));
              }
              final data = snap.data!;
              final isOwner = data.me.role == 'office_owner';
              if (data.users.isEmpty) {
                return const Center(child: Text('لا يوجد مستخدمين'));
              }
              return ListView.separated(
                itemCount: data.users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final u = data.users[i];
                  final isStaff = u.role == 'staff';
                  final display = (u.fullName != null && u.fullName!.trim().isNotEmpty) ? u.fullName! : u.email;
                  final initial = display.isNotEmpty ? display.substring(0, 1) : '?';
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  display,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  u.email,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(_roleLabel(u.role)),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      side: BorderSide.none,
                                      backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.5),
                                    ),
                                    Chip(
                                      label: Text(u.isActive ? 'نشط' : 'مُعطّل'),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      side: BorderSide.none,
                                      backgroundColor: u.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : scheme.surfaceContainerHighest,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              if (isOwner && isStaff)
                                OutlinedButton.icon(
                                  onPressed: () => _editStaffName(u),
                                  icon: const Icon(Icons.badge_outlined, size: 18),
                                  label: const Text('الاسم'),
                                ),
                              if (isOwner)
                                FilledButton.tonalIcon(
                                  onPressed: () => _editPermissions(data, u),
                                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                                  label: const Text('الصلاحيات'),
                                ),
                              if (isOwner && isStaff)
                                TextButton(
                                  onPressed: u.isActive ? () => _disableUser(u) : null,
                                  child: const Text('تعطيل'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmployeesData {
  const _EmployeesData({required this.users, required this.catalog, required this.me});
  final List<OfficeUserDto> users;
  final List<PermissionCatalogItemDto> catalog;
  final MeDto me;
}

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة موظف'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم (يظهر داخل البرنامج)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            final email = _email.text.trim();
            final password = _password.text;
            if (name.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم صحيح')));
              return;
            }
            if (!email.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب بريد صحيح')));
              return;
            }
            if (password.length < 8) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور ٨ أحرف على الأقل')));
              return;
            }
            Navigator.of(context).pop(_CreateEmployeeResult(fullName: name, email: email, password: password));
          },
          child: const Text('إنشاء'),
        ),
      ],
    );
  }
}

class _CreateEmployeeResult {
  const _CreateEmployeeResult({required this.fullName, required this.email, required this.password});
  final String fullName;
  final String email;
  final String password;
}

String _permGroupLabel(String key) {
  if (key.startsWith('dashboard')) return 'لوحة التحكم';
  if (key.startsWith('clients')) return 'الموكلين';
  if (key.startsWith('cases')) return 'القضايا';
  if (key.startsWith('sessions')) return 'الجلسات';
  if (key == 'accounts.read') return 'الصندوق والمعاملات';
  if (key.startsWith('finance')) return 'التقارير والبيانات الحساسة';
  if (key.startsWith('employees')) return 'الموظفين';
  if (key.startsWith('custody')) return 'العُهد';
  if (key.startsWith('settings')) return 'الإعدادات';
  return 'أخرى';
}

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({
    required this.title,
    required this.catalog,
    required this.initial,
    required this.catalogKeys,
  });

  final String title;
  final List<PermissionCatalogItemDto> catalog;
  final List<String> initial;
  final Set<String> catalogKeys;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late final Set<String> _selected = widget.initial.toSet();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyKeys(Set<String> keys) {
    setState(() {
      _selected
        ..clear()
        ..addAll(keys.where(widget.catalogKeys.contains));
    });
  }

  static const _cashierNoSensitive = {
    'dashboard.view',
    'clients.read',
    'cases.read',
    'accounts.read',
    'custody.me',
    'custody.spend.create',
  };

  static const _caseTeamNoSensitive = {
    ..._cashierNoSensitive,
    'cases.create',
    'cases.upload',
    'sessions.update',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final grouped = <String, List<PermissionCatalogItemDto>>{};
    for (final p in widget.catalog) {
      final g = _permGroupLabel(p.key);
      grouped.putIfAbsent(g, () => []).add(p);
    }
    for (final e in grouped.entries) {
      e.value.sort((a, b) => a.label.compareTo(b.label));
    }
    final groupNames = grouped.keys.toList()..sort();

    bool matches(PermissionCatalogItemDto p) {
      if (q.isEmpty) return true;
      if (p.key.toLowerCase().contains(q) || p.label.toLowerCase().contains(q)) return true;
      return labelForPermKey(p.key).toLowerCase().contains(q);
    }

    final tiles = <Widget>[];
    for (final gName in groupNames) {
      final items = grouped[gName]!.where(matches).toList();
      if (items.isEmpty) continue;
      tiles.add(
        ExpansionTile(
          initiallyExpanded: q.isNotEmpty,
          title: Text('$gName · ${items.length}'),
          children: items
              .map(
                (p) {
                  final sensitive = p.key == 'finance.sensitive.read' || p.key == 'finance.audit.read';
                  return CheckboxListTile(
                    value: _selected.contains(p.key),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(p.key);
                        } else {
                          _selected.remove(p.key);
                        }
                      });
                    },
                    title: Text(p.label),
                    subtitle: Text(p.key, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    secondary: sensitive
                        ? Icon(Icons.shield_moon_outlined, color: theme.colorScheme.tertiary, size: 22)
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              )
              .toList(),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'بحث في الصلاحيات',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text('تطبيق سريع', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('أمين صندوق + عهدة (بدون حساس)'),
                  onPressed: () => _applyKeys(_cashierNoSensitive),
                ),
                ActionChip(
                  label: const Text('فريق قضايا + جلسات (بدون حساس)'),
                  onPressed: () => _applyKeys(_caseTeamNoSensitive),
                ),
                ActionChip(
                  label: const Text('كل الصلاحيات في الباقة ما عدا الحساسة'),
                  onPressed: () {
                    _applyKeys(widget.catalogKeys.difference({'finance.sensitive.read', 'finance.audit.read'}));
                  },
                ),
                ActionChip(
                  label: const Text('إزالة كل الحساسة'),
                  onPressed: () {
                    setState(() {
                      _selected.remove('finance.sensitive.read');
                      _selected.remove('finance.audit.read');
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يُنصح بترك «البيانات المالية الحساسة» معطّلة لأمين الصندوق، وتفعيلها فقط للمالك أو المحاسب الموثوق.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tiles.isEmpty
                  ? Center(
                      child: Text(
                        q.isEmpty ? 'لا توجد صلاحيات' : 'لا نتائج للبحث',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(children: tiles),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()..sort()),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
