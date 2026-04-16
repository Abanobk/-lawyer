import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/office_expenses_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';
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

  late final Future<List<ClientDto>> _clientsFuture = _clientsApi.list();
  int? _clientId;
  int? _caseId;

  List<ClientDto> _clients = const [];
  List<CaseDto> _cases = const [];

  Future<void> _loadCases(int clientId) async {
    setState(() {
      _caseId = null;
      _cases = const [];
    });
    final list = await _casesApi.list(clientId: clientId);
    if (!mounted) return;
    setState(() => _cases = list);
  }

  void _openCaseAccount(int caseId) {
    final code = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    if (code.isEmpty) return;
    context.go('/o/$code/accounts/case/$caseId');
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  'اختر الموكل ثم القضية لفتح حساب القضية بالتفصيل (الأتعاب والمصروفات والمتبقي).',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
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
                        _openCaseAccount(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_caseId != null)
                  FilledButton.icon(
                    onPressed: () => _openCaseAccount(_caseId!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح حساب القضية'),
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
    return const _ReportsView();
  }
}

class _ReportsView extends StatefulWidget {
  const _ReportsView();

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  final _clientsApi = ClientsApi();
  final _reportsApi = ReportsApi();

  late final Future<List<ClientDto>> _clientsFuture = _clientsApi.list();
  int? _clientId;
  ClientAccountReportDto? _clientReport;
  bool _loadingClient = false;

  int? _custodyUserId;
  List<CustodyReportItemDto> _custodyReportAll = const [];
  bool _loadingCustody = false;

  Future<void> _loadClientReport() async {
    final cid = _clientId;
    if (cid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر موكل أولاً')));
      return;
    }
    setState(() => _loadingClient = true);
    try {
      final r = await _reportsApi.clientAccount(cid);
      if (!mounted) return;
      setState(() => _clientReport = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل التقرير: $e')));
    } finally {
      if (mounted) setState(() => _loadingClient = false);
    }
  }

  Future<void> _loadCustodyReport() async {
    setState(() => _loadingCustody = true);
    try {
      final r = await _reportsApi.custody();
      if (!mounted) return;
      setState(() => _custodyReportAll = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل تقرير العهد: $e')));
    } finally {
      if (mounted) setState(() => _loadingCustody = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custodyFiltered = _custodyUserId == null
        ? _custodyReportAll
        : _custodyReportAll.where((x) => x.userId == _custodyUserId).toList();
    return FutureBuilder<List<ClientDto>>(
      future: _clientsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('تعذر تحميل الموكلين: ${snap.error}'));
        }
        final clients = snap.data ?? const <ClientDto>[];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تقارير العملاء', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownMenu<int>(
                      width: 420,
                      label: const Text('الموكل'),
                      initialSelection: _clientId,
                      dropdownMenuEntries: clients.map((c) => DropdownMenuEntry(value: c.id, label: c.fullName)).toList(),
                      onSelected: (v) => setState(() => _clientId = v),
                    ),
                    FilledButton(
                      onPressed: _loadingClient ? null : _loadClientReport,
                      child: _loadingClient ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('عرض تقرير الموكل'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _clientReport == null
                      ? const Center(child: Text('اختر موكل لعرض التقرير'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('القضية')),
                              DataColumn(label: Text('الأتعاب')),
                              DataColumn(label: Text('المحصّل')),
                              DataColumn(label: Text('المتبقي')),
                            ],
                            rows: _clientReport!.cases
                                .map(
                                  (c) => DataRow(
                                    cells: [
                                      DataCell(Text(c.caseTitle)),
                                      DataCell(Text(c.feeTotal?.toStringAsFixed(2) ?? '—')),
                                      DataCell(Text(c.incomeSum.toStringAsFixed(2))),
                                      DataCell(Text(c.remaining?.toStringAsFixed(2) ?? '—')),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Text('تقارير العهد', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownMenu<int>(
                      width: 420,
                      label: const Text('الموظف (اختياري)'),
                      initialSelection: _custodyUserId,
                      dropdownMenuEntries: [
                        const DropdownMenuEntry<int>(value: 0, label: 'الكل'),
                        ..._custodyReportAll.map((r) => DropdownMenuEntry<int>(value: r.userId, label: r.userEmail)),
                      ],
                      onSelected: (v) => setState(() => _custodyUserId = (v == null || v == 0) ? null : v),
                    ),
                    FilledButton(
                      onPressed: _loadingCustody ? null : _loadCustodyReport,
                      child: _loadingCustody ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('عرض تقرير العهد'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: custodyFiltered.isEmpty
                      ? const Center(child: Text('لا يوجد بيانات'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('المستخدم')),
                              DataColumn(label: Text('الرصيد')),
                              DataColumn(label: Text('إجمالي السلف')),
                              DataColumn(label: Text('مصروفات معتمدة')),
                              DataColumn(label: Text('مصروفات معلقة')),
                            ],
                            rows: custodyFiltered
                                .map(
                                  (r) => DataRow(
                                    cells: [
                                      DataCell(Text(r.userEmail)),
                                      DataCell(Text(r.currentBalance.toStringAsFixed(2))),
                                      DataCell(Text(r.advancesSum.toStringAsFixed(2))),
                                      DataCell(Text(r.approvedSpendsSum.toStringAsFixed(2))),
                                      DataCell(Text(r.pendingSpendsSum.toStringAsFixed(2))),
                                    ],
                                  ),
                                )
                                .toList(),
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
