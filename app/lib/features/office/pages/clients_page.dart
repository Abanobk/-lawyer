import 'package:flutter/material.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/core/theme/app_spacing.dart';
import 'package:lawyer_app/core/widgets/app_states.dart';
import 'package:lawyer_app/core/widgets/scrollable_data_table_shell.dart';
import 'package:lawyer_app/core/widgets/ui_kit.dart';
import 'package:lawyer_app/data/api/clients_api.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _api = ClientsApi();
  late Future<List<ClientDto>> _future = _api.list();

  Future<void> _reload() async {
    setState(() {
      _future = _api.list();
    });
  }

  Future<void> _openCreateDialog() async {
    final res = await showDialog<_CreateClientResult>(
      context: context,
      builder: (context) => const _CreateClientDialog(),
    );
    if (res == null) return;

    try {
      await _api.create(
        fullName: res.fullName,
        phone: res.phone,
        nationalId: res.nationalId,
        address: res.address,
        notes: res.notes,
      );
      await _reload();
      if (mounted) {
        showAppSnack(context, 'تم إضافة الموكل', tone: AppStatusTone.success);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message, tone: AppStatusTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'إدارة الموكلين',
          icon: Icons.people_outline,
          actions: [
            FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('إضافة موكل جديد'),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: Card(
            child: FutureBuilder<List<ClientDto>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AppBodyLoading(message: 'جارٍ تحميل الموكلين…');
                }
                if (snap.hasError) {
                  return AppErrorState(
                    message: '${snap.error}',
                    onRetry: _reload,
                  );
                }
                final items = snap.data ?? const <ClientDto>[];
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'لا يوجد موكلين بعد',
                    subtitle: 'ابدأ بإضافة أول موكل لمكتبك.',
                    action: FilledButton.icon(
                      onPressed: _openCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة موكل جديد'),
                    ),
                  );
                }

                return ScrollableDataTableShell(
                  table: DataTable(
                    columns: const [
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('الهاتف')),
                      DataColumn(label: Text('الرقم القومي')),
                    ],
                    rows: items
                        .map(
                          (c) => DataRow(
                            cells: [
                              DataCell(Text(c.fullName)),
                              DataCell(Text(c.phone ?? '—')),
                              DataCell(Text(c.nationalId ?? '—')),
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

class _CreateClientResult {
  const _CreateClientResult({
    required this.fullName,
    this.phone,
    this.nationalId,
    this.address,
    this.notes,
  });

  final String fullName;
  final String? phone;
  final String? nationalId;
  final String? address;
  final String? notes;
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nid = TextEditingController();
  final _addr = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nid.dispose();
    _addr.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة موكل'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الموكل *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nid,
                decoration: const InputDecoration(labelText: 'الرقم القومي'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addr,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسم الموكل')));
              return;
            }
            Navigator.of(context).pop(
              _CreateClientResult(
                fullName: name,
                phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                nationalId: _nid.text.trim().isEmpty ? null : _nid.text.trim(),
                address: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
