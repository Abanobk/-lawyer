import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/custody_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';

class CustodyPage extends StatefulWidget {
  const CustodyPage({super.key});

  @override
  State<CustodyPage> createState() => _CustodyPageState();
}

class _CustodyPageState extends State<CustodyPage> {
  final _permApi = PermissionsApi();

  late Future<UserPermissionsDto> _permsFuture = _permApi.myPermissions();

  void _reloadPerms() => setState(() => _permsFuture = _permApi.myPermissions());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserPermissionsDto>(
      future: _permsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('تعذر تحميل الصلاحيات: ${snap.error}'));
        }
        final keys = snap.data!.permissions.toSet();
        final isAdmin = keys.contains('custody.admin.view') || keys.contains('custody.admin.advance') || keys.contains('custody.admin.approve');
        final isEmployee = keys.contains('custody.me') || keys.contains('custody.spend.create');

        if (isAdmin && isEmployee) {
          return DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                TabBar(tabs: [Tab(text: 'أدمن'), Tab(text: 'موظف')]),
                SizedBox(height: 12),
                Expanded(child: TabBarView(children: [_CustodyAdminView(), _CustodyEmployeeView()])),
              ],
            ),
          );
        }
        if (isAdmin) return const _CustodyAdminView();
        if (isEmployee) return const _CustodyEmployeeView();

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ليست لديك صلاحية للوصول إلى موديول العُهد'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reloadPerms, child: const Text('تحديث')),
            ],
          ),
        );
      },
    );
  }
}

class _CustodyAdminView extends StatefulWidget {
  const _CustodyAdminView();

  @override
  State<_CustodyAdminView> createState() => _CustodyAdminViewState();
}

class _CustodyAdminViewState extends State<_CustodyAdminView> {
  final _officeApi = OfficeApi();
  final _custodyApi = CustodyApi();
  final _filesApi = CustodyFilesApi();

  late Future<_AdminData> _future = _load();

  Future<_AdminData> _load() async {
    final results = await Future.wait([
      _officeApi.users(),
      _custodyApi.listAccounts(),
      _custodyApi.listSpendsAdmin(),
    ]);
    return _AdminData(
      users: results[0] as List<OfficeUserDto>,
      accounts: results[1] as List<CustodyAccountDto>,
      spends: results[2] as List<CustodySpendDto>,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createAccount(_AdminData data) async {
    final res = await showDialog<_CreateAccountResult>(
      context: context,
      builder: (context) => _CreateAccountDialog(users: data.users, title: 'تحديد العهدة لموظف'),
    );
    if (res == null) return;
    try {
      await _custodyApi.createAccount(userId: res.userId, initialAmount: res.initialAmount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء عهدة للموظف')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addAdvance(_AdminData data) async {
    final res = await showDialog<_AdvanceResult>(
      context: context,
      builder: (context) => _AddAdvanceDialog(users: data.users),
    );
    if (res == null) return;
    try {
      await _custodyApi.addAdvance(
        userId: res.userId,
        amount: res.amount,
        occurredAt: res.occurredAt,
        notes: res.notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة السلفة')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _approve(int spendId) async {
    try {
      await _custodyApi.approveSpend(spendId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _reject(int spendId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );
    if (reason == null) return;
    try {
      await _custodyApi.rejectSpend(spendId, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الرفض')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _viewReceipts(int spendId) async {
    try {
      final receipts = await _custodyApi.listReceipts(spendId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _ReceiptsDialog(
          spendId: spendId,
          receipts: receipts,
          filesApi: _filesApi,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'العُهد (أدمن)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(onPressed: () async {
              final data = await _future;
              if (!mounted) return;
              await _createAccount(data);
            }, icon: const Icon(Icons.add), label: const Text('إنشاء عهدة لموظف')),
            FilledButton.icon(onPressed: () async {
              final data = await _future;
              if (!mounted) return;
              await _addAdvance(data);
            }, icon: const Icon(Icons.add_card), label: const Text('إضافة سلفة')),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<_AdminData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return Center(child: Text('تعذر تحميل البيانات: ${snap.error}'));
              final data = snap.data!;
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('الموظف')),
                            DataColumn(label: Text('الرصيد')),
                          ],
                          rows: data.accounts
                              .map(
                                (a) => DataRow(
                                  cells: [
                                    DataCell(Text(_nameForUserEmail(data, a.userEmail))),
                                    DataCell(Text(a.currentBalance.toStringAsFixed(2))),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('الموظف')),
                            DataColumn(label: Text('المبلغ')),
                            DataColumn(label: Text('التاريخ')),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('إيصالات')),
                            DataColumn(label: Text('إجراء')),
                          ],
                          rows: data.spends.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(Text(_nameForUserId(data, s.userId))),
                                DataCell(Text(s.amount.toStringAsFixed(2))),
                                DataCell(Text(df.format(s.occurredAt.toLocal()))),
                                DataCell(Text(_statusLabel(s.status))),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _viewReceipts(s.id),
                                    child: const Text('عرض'),
                                  ),
                                ),
                                DataCell(
                                  s.status == 'pending'
                                      ? Row(
                                          children: [
                                            TextButton(onPressed: () => _approve(s.id), child: const Text('اعتماد')),
                                            TextButton(onPressed: () => _reject(s.id), child: const Text('رفض')),
                                          ],
                                        )
                                      : const Text('—'),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _nameForUserId(_AdminData data, int userId) {
    final u = data.users.where((x) => x.id == userId).toList();
    if (u.isEmpty) return '#$userId';
    return u.first.fullName ?? u.first.email;
  }

  String _nameForUserEmail(_AdminData data, String email) {
    final u = data.users.where((x) => x.email == email).toList();
    if (u.isEmpty) return email;
    return u.first.fullName ?? u.first.email;
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'معلق';
    }
  }
}

class _AdminData {
  const _AdminData({required this.users, required this.accounts, required this.spends});
  final List<OfficeUserDto> users;
  final List<CustodyAccountDto> accounts;
  final List<CustodySpendDto> spends;
}

class _CustodyEmployeeView extends StatefulWidget {
  const _CustodyEmployeeView();

  @override
  State<_CustodyEmployeeView> createState() => _CustodyEmployeeViewState();
}

class _CustodyEmployeeViewState extends State<_CustodyEmployeeView> {
  final _custodyApi = CustodyApi();
  final _filesApi = CustodyFilesApi();

  late Future<({CustodyAccountDto account, List<CustodyLedgerEntryDto> ledger})> _future = _load();

  Future<({CustodyAccountDto account, List<CustodyLedgerEntryDto> ledger})> _load() async {
    final results = await Future.wait([
      _custodyApi.myAccount(),
      _custodyApi.myLedger(),
    ]);
    return (account: results[0] as CustodyAccountDto, ledger: results[1] as List<CustodyLedgerEntryDto>);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createSpend() async {
    final res = await showDialog<_SpendResult>(
      context: context,
      builder: (context) => const _CreateSpendDialog(),
    );
    if (res == null) return;
    try {
      final upload = await FilePicker.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
      final file = (upload?.files == null || upload!.files.isEmpty) ? null : upload.files.first;
      if (file == null || file.bytes == null || file.bytes!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر إيصال/مستند للصرف')));
        return;
      }
      final spend = await _custodyApi.createSpend(
        amount: res.amount,
        occurredAt: res.occurredAt,
        description: res.description,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المصروف (معلق للمراجعة)')));

      await _filesApi.uploadReceipt(spendId: spend.id, file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الإيصال')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on CustodyFilesApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'عهدي (موظف)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FilledButton.icon(onPressed: _createSpend, icon: const Icon(Icons.add), label: const Text('تسجيل مصروف')),
            const SizedBox(width: 8),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: FutureBuilder<({CustodyAccountDto account, List<CustodyLedgerEntryDto> ledger})>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return Center(child: Text('تعذر تحميل العهدة: ${snap.error}'));
                final data = snap.data!;
                final acc = data.account;
                final ledger = data.ledger;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text('إجمالي العهدة (الرصيد الحالي)'),
                          subtitle: Text(acc.currentBalance.toStringAsFixed(2)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('حركة العهدة', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (ledger.isEmpty)
                        const Text('لا توجد حركة بعد')
                      else
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('التاريخ')),
                            DataColumn(label: Text('النوع')),
                            DataColumn(label: Text('المبلغ')),
                            DataColumn(label: Text('وصف')),
                            DataColumn(label: Text('الحالة')),
                          ],
                          rows: ledger.map((e) {
                            final kindLabel = e.kind == 'advance' ? 'سلفة/إضافة' : 'مصروف';
                            final statusLabel = e.kind == 'spend' ? _spendStatusLabel(e.status) : '—';
                            return DataRow(
                              cells: [
                                DataCell(Text(df.format(e.occurredAt.toLocal()))),
                                DataCell(Text(kindLabel)),
                                DataCell(Text(e.amount.toStringAsFixed(2))),
                                DataCell(Text(e.description ?? '—')),
                                DataCell(Text(statusLabel)),
                              ],
                            );
                          }).toList(),
                        ),
                    ],
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

String _spendStatusLabel(String? s) {
  switch (s) {
    case 'approved':
      return 'معتمد';
    case 'rejected':
      return 'مرفوض';
    case 'pending':
      return 'معلق';
    default:
      return '—';
  }
}

class _CreateAccountResult {
  const _CreateAccountResult({required this.userId, required this.initialAmount});
  final int userId;
  final double initialAmount;
}

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog({required this.users, required this.title});
  final List<OfficeUserDto> users;
  final String title;

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  int? _userId;
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<int>(
              initialSelection: _userId,
              label: const Text('الموظف'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries:
                  widget.users.map((u) => DropdownMenuEntry(value: u.id, label: u.fullName ?? u.email)).toList(),
              onSelected: (v) => setState(() => _userId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'العهدة كام؟'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final uid = _userId;
            final amt = double.tryParse(_amount.text.trim());
            if (uid == null || amt == null || amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل البيانات')));
              return;
            }
            Navigator.of(context).pop(_CreateAccountResult(userId: uid, initialAmount: amt));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _AdvanceResult {
  const _AdvanceResult({required this.userId, required this.amount, required this.occurredAt, this.notes});
  final int userId;
  final double amount;
  final DateTime occurredAt;
  final String? notes;
}

class _AddAdvanceDialog extends StatefulWidget {
  const _AddAdvanceDialog({required this.users});
  final List<OfficeUserDto> users;

  @override
  State<_AddAdvanceDialog> createState() => _AddAdvanceDialogState();
}

class _AddAdvanceDialogState extends State<_AddAdvanceDialog> {
  int? _userId;
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  final DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة سلفة'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<int>(
              initialSelection: _userId,
              label: const Text('الموظف'),
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: widget.users.map((u) => DropdownMenuEntry(value: u.id, label: u.email)).toList(),
              onSelected: (v) => setState(() => _userId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'المبلغ'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final uid = _userId;
            final amt = double.tryParse(_amount.text.trim());
            if (uid == null || amt == null || amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل البيانات')));
              return;
            }
            Navigator.of(context).pop(_AdvanceResult(userId: uid, amount: amt, occurredAt: _date, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim()));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _SpendResult {
  const _SpendResult({required this.amount, required this.occurredAt, this.description});
  final double amount;
  final DateTime occurredAt;
  final String? description;
}

class _CreateSpendDialog extends StatefulWidget {
  const _CreateSpendDialog();

  @override
  State<_CreateSpendDialog> createState() => _CreateSpendDialogState();
}

class _CreateSpendDialogState extends State<_CreateSpendDialog> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل مصروف من العهدة'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'المبلغ'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amount.text.trim());
            if (amt == null || amt <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب مبلغ صحيح')));
              return;
            }
            Navigator.of(context).pop(_SpendResult(amount: amt, occurredAt: _date, description: _desc.text.trim().isEmpty ? null : _desc.text.trim()));
          },
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('رفض المصروف'),
      content: SizedBox(
        width: 640,
        child: TextField(
          controller: _reason,
          decoration: const InputDecoration(labelText: 'سبب الرفض (اختياري)'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('رفض'),
        ),
      ],
    );
  }
}

class _ReceiptsDialog extends StatefulWidget {
  const _ReceiptsDialog({
    required this.spendId,
    required this.receipts,
    required this.filesApi,
  });

  final int spendId;
  final List<CustodyReceiptDto> receipts;
  final CustodyFilesApi filesApi;

  @override
  State<_ReceiptsDialog> createState() => _ReceiptsDialogState();
}

class _ReceiptsDialogState extends State<_ReceiptsDialog> {
  Uint8List? _previewBytes;
  String? _previewContentType;
  bool _loading = false;

  Future<void> _preview(int fileId) async {
    setState(() => _loading = true);
    try {
      final res = await widget.filesApi.downloadReceipt(fileId);
      setState(() {
        _previewBytes = res.$1;
        _previewContentType = res.$2;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('إيصالات المصروف #${widget.spendId}'),
      content: SizedBox(
        width: 900,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: widget.receipts
                    .map(
                      (r) => ListTile(
                        title: Text(r.originalName),
                        subtitle: Text(r.contentType ?? '—'),
                        trailing: TextButton(
                          onPressed: _loading ? null : () => _preview(r.id),
                          child: const Text('عرض'),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : _previewBytes == null
                          ? const Text('اختر إيصال لعرضه')
                          : (_previewContentType?.startsWith('image/') ?? false)
                              ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                              : const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('المعاينة داخل التطبيق مدعومة للصور فقط. يمكن تنزيل الملف من السيرفر عند الحاجة.'),
                                ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
      ],
    );
  }
}

