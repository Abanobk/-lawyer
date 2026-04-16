import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/office_expenses_api.dart';
import 'package:lawyer_app/data/api/transactions_api.dart';
import 'package:lawyer_app/features/office/pages/custody_page.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  static int _tabIndexFromUri(Uri uri) {
    final v = uri.queryParameters['tab'];
    switch (v) {
      case 'receive':
        return 0;
      case 'expenses':
        return 1;
      case 'custody':
        return 2;
      case 'reports':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final initial = _tabIndexFromUri(uri);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'الإدارة المالية',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DefaultTabController(
            length: 4,
            initialIndex: initial,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'استلام نقدية'),
                    Tab(text: 'صرف نقدية'),
                    Tab(text: 'العُهد'),
                    Tab(text: 'تقارير'),
                  ],
                ),
                const SizedBox(height: 12),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _ReceiveCashTab(),
                      _OfficeExpensesTab(),
                      CustodyPage(),
                      _ReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiveCashTab extends StatefulWidget {
  const _ReceiveCashTab();

  @override
  State<_ReceiveCashTab> createState() => _ReceiveCashTabState();
}

class _ReceiveCashTabState extends State<_ReceiveCashTab> {
  final _clientsApi = ClientsApi();
  final _casesApi = CasesApi();
  final _txApi = TransactionsApi();

  late final Future<List<ClientDto>> _clientsFuture = _clientsApi.list();
  int? _clientId;
  int? _caseId;

  List<ClientDto> _clients = const [];
  List<CaseDto> _cases = const [];
  List<CaseTransactionDto> _txs = const [];

  final _amount = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCases(int clientId) async {
    setState(() {
      _caseId = null;
      _cases = const [];
      _txs = const [];
    });
    final list = await _casesApi.list(clientId: clientId);
    if (!mounted) return;
    setState(() => _cases = list);
  }

  Future<void> _loadTxs(int caseId) async {
    setState(() => _txs = const []);
    final list = await _txApi.listForCase(caseId);
    if (!mounted) return;
    setState(() => _txs = list);
  }

  double _incomeSum() => _txs.where((t) => t.direction == 'income').fold(0.0, (a, b) => a + b.amount);

  CaseDto? _selectedCase() {
    final id = _caseId;
    if (id == null) return null;
    for (final c in _cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _submit() async {
    final caseId = _caseId;
    final amt = double.tryParse(_amount.text.trim());
    if (caseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر قضية أولاً')));
      return;
    }
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب مبلغ صحيح')));
      return;
    }
    try {
      await _txApi.create(caseId: caseId, direction: 'income', amount: amt, description: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      if (!mounted) return;
      _amount.clear();
      _notes.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاستلام')));
      await _loadTxs(caseId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل الاستلام: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final selected = _selectedCase();
    final feeTotal = selected?.feeTotal ?? 0;
    final income = _incomeSum();
    final remaining = (selected?.feeTotal == null) ? null : (feeTotal - income);

    return FutureBuilder<List<ClientDto>>(
      future: _clientsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('تعذر تحميل الموكلين: ${snap.error}'));
        }
        _clients = snap.data ?? const [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownMenu<int>(
                      width: 360,
                      label: const Text('الموكل'),
                      initialSelection: _clientId,
                      dropdownMenuEntries: _clients.map((c) => DropdownMenuEntry(value: c.id, label: c.fullName)).toList(),
                      onSelected: (v) async {
                        if (v == null) return;
                        setState(() => _clientId = v);
                        await _loadCases(v);
                      },
                    ),
                    DropdownMenu<int>(
                      width: 420,
                      label: const Text('القضية'),
                      initialSelection: _caseId,
                      dropdownMenuEntries: _cases.map((c) => DropdownMenuEntry(value: c.id, label: c.title)).toList(),
                      onSelected: (v) async {
                        if (v == null) return;
                        setState(() => _caseId = v);
                        await _loadTxs(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text('الأتعاب المتفق عليها: ${selected?.feeTotal?.toStringAsFixed(2) ?? '—'}'),
                        Text('المحصّل: ${income.toStringAsFixed(2)}'),
                        if (remaining != null) Text('المتبقي: ${remaining.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _amount,
                        decoration: const InputDecoration(labelText: 'المبلغ'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    SizedBox(
                      width: 520,
                      child: TextField(
                        controller: _notes,
                        decoration: const InputDecoration(labelText: 'ملحوظات (اختياري)'),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('استلام'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _txs.isEmpty
                      ? const Center(child: Text('لا يوجد معاملات بعد'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('النوع')),
                              DataColumn(label: Text('المبلغ')),
                              DataColumn(label: Text('ملحوظات')),
                            ],
                            rows: _txs.map((t) {
                              final kind = t.direction == 'income' ? 'استلام' : 'مصروف';
                              return DataRow(
                                cells: [
                                  DataCell(Text(df.format(t.occurredAt.toLocal()))),
                                  DataCell(Text(kind)),
                                  DataCell(Text(t.amount.toStringAsFixed(2))),
                                  DataCell(Text(t.description ?? '—')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OfficeExpensesTab extends StatelessWidget {
  const _OfficeExpensesTab();

  @override
  Widget build(BuildContext context) {
    return const _OfficeExpensesView();
  }
}

class _OfficeExpensesView extends StatefulWidget {
  const _OfficeExpensesView();

  @override
  State<_OfficeExpensesView> createState() => _OfficeExpensesViewState();
}

class _OfficeExpensesViewState extends State<_OfficeExpensesView> {
  final _api = OfficeExpensesApi();
  final _files = OfficeExpenseFilesApi();

  late Future<List<OfficeExpenseDto>> _future = _api.list();

  final _amount = TextEditingController();
  final _desc = TextEditingController();

  void _reload() => setState(() => _future = _api.list());

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final amt = double.tryParse(_amount.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب مبلغ صحيح')));
      return;
    }
    final upload = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    final file = (upload?.files == null || upload!.files.isEmpty) ? null : upload.files.first;
    if (file == null || file.bytes == null || file.bytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر إيصال/مستند للمصروف')));
      return;
    }
    try {
      final exp = await _api.create(amount: amt, description: _desc.text.trim().isEmpty ? null : _desc.text.trim());
      await _files.uploadReceipt(expenseId: exp.id, file: file);
      if (!mounted) return;
      _amount.clear();
      _desc.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل المصروف ورفع الإيصال')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تسجيل المصروف: $e')));
    }
  }

  Future<void> _viewReceipts(int expenseId) async {
    try {
      final receipts = await _api.listReceipts(expenseId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _OfficeExpenseReceiptsDialog(
          expenseId: expenseId,
          receipts: receipts,
          filesApi: _files,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل الإيصالات: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _amount,
                    decoration: const InputDecoration(labelText: 'المبلغ'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                SizedBox(
                  width: 520,
                  child: TextField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('تسجيل مصروف + رفع إيصال'),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<OfficeExpenseDto>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('تعذر تحميل مصروفات المكتب: ${snap.error}'));
                  }
                  final items = snap.data ?? const <OfficeExpenseDto>[];
                  if (items.isEmpty) {
                    return const Center(child: Text('لا يوجد مصروفات بعد'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('المبلغ')),
                        DataColumn(label: Text('الوصف')),
                        DataColumn(label: Text('إيصالات')),
                      ],
                      rows: items
                          .map(
                            (e) => DataRow(
                              cells: [
                                DataCell(Text(df.format(e.occurredAt.toLocal()))),
                                DataCell(Text(e.amount.toStringAsFixed(2))),
                                DataCell(Text(e.description ?? '—')),
                                DataCell(
                                  TextButton(
                                    onPressed: () => _viewReceipts(e.id),
                                    child: const Text('عرض'),
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
          ],
        ),
      ),
    );
  }
}

class _OfficeExpenseReceiptsDialog extends StatefulWidget {
  const _OfficeExpenseReceiptsDialog({
    required this.expenseId,
    required this.receipts,
    required this.filesApi,
  });

  final int expenseId;
  final List<OfficeExpenseReceiptDto> receipts;
  final OfficeExpenseFilesApi filesApi;

  @override
  State<_OfficeExpenseReceiptsDialog> createState() => _OfficeExpenseReceiptsDialogState();
}

class _OfficeExpenseReceiptsDialogState extends State<_OfficeExpenseReceiptsDialog> {
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
      title: Text('إيصالات المصروف #${widget.expenseId}'),
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
                                  child: Text('المعاينة داخل التطبيق مدعومة للصور فقط. يمكن تنزيل الملف عند الحاجة.'),
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

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('قريبًا: تقارير العملاء وتقارير العهد.'),
      ),
    );
  }
}
