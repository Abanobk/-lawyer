import 'package:flutter/material.dart';
import 'package:lawyer_app/data/api/api_client.dart';
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

  late Future<_EmployeesData> _future = _load();

  Future<_EmployeesData> _load() async {
    final results = await Future.wait([
      _officeApi.users(),
      _permApi.catalog(),
    ]);
    return _EmployeesData(
      users: results[0] as List<OfficeUserDto>,
      catalog: results[1] as List<PermissionCatalogItemDto>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createEmployee() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateEmployeeDialog(),
    );
    if (email == null) return;
    try {
      final res = await _officeApi.createUser(email: email);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تم إنشاء الموظف'),
          content: SelectableText(
            'البريد: ${res.email}\n'
            'كلمة المرور المؤقتة: ${res.tempPassword}\n\n'
            'انسخ كلمة المرور الآن (لن تظهر مرة أخرى).',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('تم')),
          ],
        ),
      );
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
                if (data.users.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمين'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('البريد')),
                      DataColumn(label: Text('الدور')),
                      DataColumn(label: Text('الصلاحيات')),
                    ],
                    rows: data.users
                        .map(
                          (u) => DataRow(
                            cells: [
                              DataCell(Text(u.email)),
                              DataCell(Text(u.role)),
                              DataCell(
                                TextButton(
                                  onPressed: () => _editPermissions(data, u),
                                  child: const Text('تعديل'),
                                ),
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
  const _EmployeesData({required this.users, required this.catalog});
  final List<OfficeUserDto> users;
  final List<PermissionCatalogItemDto> catalog;
}

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة موظف'),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
          keyboardType: TextInputType.emailAddress,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final v = _email.text.trim();
            if (!v.contains('@')) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب بريد صحيح')));
              return;
            }
            Navigator.of(context).pop(v);
          },
          child: const Text('إنشاء'),
        ),
      ],
    );
  }
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

