import 'package:flutter/material.dart';
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

  Future<void> _editPermissions(_EmployeesData data, OfficeUserDto user) async {
    final current = await _permApi.getForUser(user.id);
    if (!mounted) return;
    final updated = await showDialog<List<String>>(
      context: context,
      builder: (context) => _PermissionsDialog(
        title: 'صلاحيات: ${user.email}',
        catalog: data.catalog,
        initial: current.permissions,
      ),
    );
    if (updated == null) return;
    try {
      await _permApi.setForUser(user.id, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصلاحيات')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'إدارة الموظفين والصلاحيات',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _createEmployee,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة موظف'),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
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
                final isAdmin = data.me.role == 'office_owner';
                if (data.users.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمين'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('البريد')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('الدور')),
                      DataColumn(label: Text('الصلاحيات')),
                      DataColumn(label: Text('إزالة')),
                    ],
                    rows: data.users
                        .map(
                          (u) => DataRow(
                            cells: [
                              DataCell(Text(u.fullName ?? '—')),
                              DataCell(Text(u.email)),
                              DataCell(Text(u.isActive ? 'نشط' : 'مُعطّل')),
                              DataCell(Text(u.role)),
                              DataCell(
                                TextButton(
                                  onPressed: () => _editPermissions(data, u),
                                  child: const Text('تعديل'),
                                ),
                              ),
                              DataCell(
                                isAdmin && u.role == 'staff'
                                    ? TextButton(
                                        onPressed: u.isActive ? () => _disableUser(u) : null,
                                        child: const Text('تعطيل'),
                                      )
                                    : const Text('—'),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
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

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({
    required this.title,
    required this.catalog,
    required this.initial,
  });

  final String title;
  final List<PermissionCatalogItemDto> catalog;
  final List<String> initial;

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late final Set<String> _selected = widget.initial.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 720,
        child: ListView(
          shrinkWrap: true,
          children: widget.catalog
              .map(
                (p) => CheckboxListTile(
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
                  subtitle: Text(p.key),
                ),
              )
              .toList(),
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

