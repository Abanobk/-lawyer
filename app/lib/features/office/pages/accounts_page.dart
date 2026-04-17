import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/finance_api.dart';
import 'package:lawyer_app/data/api/office_expenses_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';
import 'package:lawyer_app/features/office/pages/custody_page.dart';
import 'package:lawyer_app/features/office/pages/petty_cash_page.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  static int _tabIndexFromUri(Uri uri) {
    final v = uri.queryParameters['tab'];
    switch (v) {
      case 'summary':
        return 0;
      case 'receive':
        return 1;
      case 'expenses':
        return 2;
      case 'petty':
        return 3;
      case 'custody':
        return 4;
      case 'reports':
        return 5;
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
            length: 6,
            initialIndex: initial,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'ملخص مالي'),
                    Tab(text: 'استلام نقدية'),
                    Tab(text: 'صرف نقدية'),
                    Tab(text: 'النثرية'),
                    Tab(text: 'العُهد'),
                    Tab(text: 'تقارير'),
                  ],
                ),
                const SizedBox(height: 12),
                const Expanded(
                  child: TabBarView(
                    children: [
                      _FinanceOverviewTab(),
                      _ReceiveCashTab(),
                      _OfficeExpensesTab(),
                      PettyCashPage(),
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

/// المرحلة أ — ملخص موحّد + دفتر حركة (عبر `/finance/*`).
class _FinanceOverviewTab extends StatefulWidget {
  const _FinanceOverviewTab();

  @override
  State<_FinanceOverviewTab> createState() => _FinanceOverviewTabState();
}

class _FinanceOverviewTabState extends State<_FinanceOverviewTab> {
  final _api = FinanceApi();
  final _money = NumberFormat('#,##0.00', 'ar');
  final _df = DateFormat('yyyy-MM-dd');

  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();
  int? _caseIdFilter;

  FinancialSummaryDto? _summary;
  List<FinancialMovementDto> _movements = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readUriAndLoad());
  }

  void _readUriAndLoad() {
    final uri = GoRouterState.of(context).uri;
    final raw = uri.queryParameters['case_id'];
    final id = int.tryParse(raw ?? '');
    setState(() => _caseIdFilter = id);
    _load();
  }

  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _from = p);
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _to = p);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime(_from.year, _from.month, _from.day);
      final to = DateTime(_to.year, _to.month, _to.day);
      final sum = await _api.summary(from: from, to: to, caseId: _caseIdFilter);
      final mov = await _api.movements(from: from, to: to, caseId: _caseIdFilter, limit: 250);
      if (!mounted) return;
      setState(() {
        _summary = sum;
        _movements = mov;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final from = DateTime(_from.year, _from.month, _from.day);
      final to = DateTime(_to.year, _to.month, _to.day);
      final csv = await _api.movementsCsv(from: from, to: to, caseId: _caseIdFilter);
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ ملف CSV — الصقه في Excel أو حفظه كملف .csv')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
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
            Text(
              'ملخص مالي موحّد للفترة (قضايا + مكتب + عهد عند توفر الصلاحية).',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFrom,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('من ${_df.format(_from)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTo,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text('إلى ${_df.format(_to)}'),
                ),
                if (_caseIdFilter != null)
                  Chip(
                    label: Text('قضية #$_caseIdFilter'),
                    onDeleted: () => setState(() => _caseIdFilter = null),
                  ),
                FilledButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _exportCsv,
                  icon: const Icon(Icons.copy),
                  label: const Text('تصدير CSV (نسخ)'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 12),
              if (!_summary!.includesCustody)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'تنبيه: ليس لديك صلاحية عرض العهد — الملخص يشمل القضايا والمصروفات العامة للمكتب فقط.',
                    style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w600),
                  ),
                ),
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cards = [
                    _finCard(context, 'إيرادات القضايا', _summary!.totalCaseIncome, const Color(0xFF16A34A)),
                    _finCard(context, 'مصروفات على القضايا', _summary!.totalCaseExpense, const Color(0xFFDC2626)),
                    _finCard(context, 'مصروفات المكتب', _summary!.totalOfficeExpense, const Color(0xFFEA580C)),
                    _finCard(context, 'صافي القضايا', _summary!.netCase, const Color(0xFF1E40AF)),
                    _finCard(context, 'صافي تشغيلي مبسّط', _summary!.netOperatingSimple, const Color(0xFF7C3AED)),
                    _finCard(context, 'تغذية نثرية', _summary!.totalPettyTopUps, const Color(0xFF0891B2)),
                    _finCard(context, 'صرف نثرية', _summary!.totalPettySpends, const Color(0xFFC026D3)),
                    _finCard(context, 'تسويات نثرية (صافي)', _summary!.totalPettySettlementNet, const Color(0xFF4D7C0F)),
                    if (_summary!.includesCustody) ...[
                      _finCard(context, 'سلف عهد', _summary!.totalCustodyAdvances, const Color(0xFF0D9488)),
                      _finCard(context, 'مصروف عهد معتمد', _summary!.totalCustodySpendsApproved, const Color(0xFFBE185D)),
                      _finCard(context, 'مصروف عهد معلّق', _summary!.totalCustodySpendsPending, const Color(0xFFCA8A04)),
                    ],
                  ];
                  if (w >= 900) {
                    return Wrap(spacing: 10, runSpacing: 10, children: cards.map((e) => SizedBox(width: 200, child: e)).toList());
                  }
                  return Column(children: cards.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: e)).toList());
                },
              ),
            ],
            const SizedBox(height: 16),
            Text('آخر الحركات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading && _movements.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _movements.isEmpty
                      ? const Center(child: Text('لا توجد حركات في هذه الفترة'))
                      : Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('النوع')),
                                DataColumn(label: Text('اتجاه')),
                                DataColumn(label: Text('مبلغ')),
                                DataColumn(label: Text('خزينة')),
                                DataColumn(label: Text('قضية')),
                                DataColumn(label: Text('بيان')),
                              ],
                              rows: _movements
                                  .map(
                                    (m) => DataRow(
                                      cells: [
                                        DataCell(Text(_df.format(m.occurredAt.toLocal()))),
                                        DataCell(Text(m.kindLabelAr, style: const TextStyle(fontSize: 12))),
                                        DataCell(Text(m.direction == 'income' ? 'وارد' : 'صادر')),
                                        DataCell(Text('${_money.format(m.amount)} ج.م')),
                                        DataCell(Text(m.affectsOfficeCash ? 'نعم' : 'لا')),
                                        DataCell(Text(m.caseId != null ? '${m.caseId}' : '—')),
                                        DataCell(SizedBox(width: 220, child: Text(m.description ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis))),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finCard(BuildContext context, String label, double value, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${_money.format(value)} ج.م', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
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
