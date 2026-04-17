import 'package:flutter/material.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/core/widgets/scrollable_data_table_shell.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الموكل')));
      }
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
            Icon(Icons.people_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'إدارة الموكلين',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('إضافة موكل جديد'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: FutureBuilder<List<ClientDto>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('تعذر تحميل الموكلين: ${snap.error}'));
                }
                final items = snap.data ?? const <ClientDto>[];
                if (items.isEmpty) {
                  return const Center(child: Text('لا يوجد موكلين بعد'));
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
