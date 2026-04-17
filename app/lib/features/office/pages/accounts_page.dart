import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/finance_api.dart';
import 'package:lawyer_app/data/api/office_expenses_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';
import 'package:lawyer_app/features/office/pages/custody_page.dart';
import 'package:lawyer_app/features/office/pages/petty_cash_page.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  static int tabIndexFromUri(Uri uri) {
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

  static String tabQueryValueForIndex(int index) {
    switch (index) {
      case 0:
        return 'summary';
      case 1:
        return 'receive';
      case 2:
        return 'expenses';
      case 3:
        return 'petty';
      case 4:
        return 'custody';
      case 5:
        return 'reports';
      default:
        return 'summary';
    }
  }

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _controllerReady = false;
  bool _ignoreTabListener = false;

  @override
  void dispose() {
    _tabController?.removeListener(_onTabControllerTick);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabControllerTick() {
    final c = _tabController;
    if (c == null || c.indexIsChanging || _ignoreTabListener) return;
    final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    if (officeCode.isEmpty) return;
    final uri = GoRouterState.of(context).uri;
    final fromUri = AccountsPage.tabIndexFromUri(uri);
    if (c.index == fromUri) return;

    final q = Map<String, String>.from(uri.queryParameters);
    q['tab'] = AccountsPage.tabQueryValueForIndex(c.index);
    context.go(Uri(path: '/o/$officeCode/accounts', queryParameters: q).toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final i = AccountsPage.tabIndexFromUri(GoRouterState.of(context).uri);
    if (!_controllerReady) {
      _tabController = TabController(length: 6, vsync: this, initialIndex: i);
      _tabController!.addListener(_onTabControllerTick);
      _controllerReady = true;
      return;
    }
    final c = _tabController!;
    if (c.index != i) {
      _ignoreTabListener = true;
      c.index = i;
      _ignoreTabListener = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _tabController;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                controller: c,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'ملخص مالي'),
                  Tab(text: 'استلام نقدية'),
                  Tab(text: 'صرف نقدية'),
                  Tab(text: 'النثرية'),
                  Tab(text: 'العُهد'),
                  Tab(text: 'تقارير'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: c,
                  children: const [
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
  final _casesApi = CasesApi();
  final _financeApi = FinanceApi();
  final _moneyJ = NumberFormat('#,##0.00', 'ar');
  final _dfJ = DateFormat('yyyy-MM-dd');

  late final Future<List<ClientDto>> _clientsFuture = _clientsApi.list();
  int? _clientId;
  ClientAccountReportDto? _clientReport;
  bool _loadingClient = false;

  int? _custodyUserId;
  List<CustodyReportItemDto> _custodyReportAll = const [];
  bool _loadingCustody = false;

  DateTime _jFrom = DateTime.now().subtract(const Duration(days: 29));
  DateTime _jTo = DateTime.now();
  IncomeStatementDto? _incomeStmt;
  List<CashFlowDayDto> _cashFlow = const [];
  List<CaseDto> _casesForJ = const [];
  int? _caseIdJ;
  CaseFinancialSummaryDto? _caseFinSum;
  bool _loadingJ = false;

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

  Future<void> _loadCasesForJ(int clientId) async {
    try {
      final list = await _casesApi.list(clientId: clientId);
      if (!mounted) return;
      setState(() => _casesForJ = list);
    } catch (_) {
      if (mounted) setState(() => _casesForJ = const []);
    }
  }

  Future<void> _loadPhaseJReports() async {
    setState(() => _loadingJ = true);
    try {
      final from = DateTime(_jFrom.year, _jFrom.month, _jFrom.day);
      final to = DateTime(_jTo.year, _jTo.month, _jTo.day);
      final inc = await _financeApi.incomeStatement(from: from, to: to);
      final cf = await _financeApi.cashFlowDaily(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _incomeStmt = inc;
        _cashFlow = cf;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحميل التقارير المالية: $e')));
    } finally {
      if (mounted) setState(() => _loadingJ = false);
    }
  }

  Future<void> _loadCaseFinancialSummary() async {
    final id = _caseIdJ;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر قضية لعرض الملخص')));
      return;
    }
    setState(() => _loadingJ = true);
    try {
      final s = await _financeApi.caseFinancialSummary(id);
      if (!mounted) return;
      setState(() => _caseFinSum = s);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل ملخص القضية: $e')));
    } finally {
      if (mounted) setState(() => _loadingJ = false);
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
                Text('تقارير مالية — المرحلة ج', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'قائمة دخل مبسطة، تدفق نقدي يومي (خزينة رئيسية)، وملخص مالي لقضية واحدة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _jFrom,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _jFrom = p);
                      },
                      child: Text('من ${_dfJ.format(_jFrom)}'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _jTo,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (p != null) setState(() => _jTo = p);
                      },
                      child: Text('إلى ${_dfJ.format(_jTo)}'),
                    ),
                    FilledButton(
                      onPressed: _loadingJ ? null : _loadPhaseJReports,
                      child: _loadingJ
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('قائمة الدخل + التدفق النقدي'),
                    ),
                  ],
                ),
                if (_incomeStmt != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('قائمة الدخل المبسطة', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _jLine(context, 'إيرادات تحصيلات القضايا', _incomeStmt!.revenueCaseIncome),
                          _jLine(context, 'مصروفات مباشرة على القضايا', -_incomeStmt!.costsCaseExpenses),
                          const Divider(height: 16),
                          _jLine(context, 'هامش القضايا (إيراد − مصروف قضية)', _incomeStmt!.grossMarginCases, bold: true),
                          const Divider(height: 16),
                          _jLine(context, 'مصروفات المكتب التشغيلية', -_incomeStmt!.expenseOffice),
                          _jLine(context, 'تغذية النثرية (خروج من الخزينة)', -_incomeStmt!.expensePettyTopUps),
                          if (_incomeStmt!.includesCustody)
                            _jLine(context, 'سلف العهد (خروج من الخزينة)', -_incomeStmt!.expenseCustodyAdvances),
                          const Divider(height: 16),
                          _jLine(context, 'صافي بعد خروج الخزينة الرئيسية', _incomeStmt!.netAfterOperatingMainCash, bold: true),
                          const SizedBox(height: 8),
                          Text(_incomeStmt!.noteAr, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_cashFlow.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('التدفق النقدي اليومي (وارد تحصيل / صادر خزينة)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('اليوم')),
                        DataColumn(label: Text('وارد')),
                        DataColumn(label: Text('صادر')),
                        DataColumn(label: Text('الصافي')),
                      ],
                      rows: _cashFlow
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.day)),
                                DataCell(Text(_moneyJ.format(r.inflow))),
                                DataCell(Text(_moneyJ.format(r.outflow))),
                                DataCell(Text(_moneyJ.format(r.net), style: TextStyle(fontWeight: r.net >= 0 ? FontWeight.w600 : FontWeight.normal))),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text('ملخص مالي لقضية', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('اختر الموكل أعلاه ثم القضية.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownMenu<int>(
                      width: 400,
                      enabled: _casesForJ.isNotEmpty,
                      label: const Text('القضية'),
                      initialSelection: _caseIdJ,
                      dropdownMenuEntries: _casesForJ.map((c) => DropdownMenuEntry(value: c.id, label: c.title)).toList(),
                      onSelected: (v) => setState(() {
                        _caseIdJ = v;
                        _caseFinSum = null;
                      }),
                    ),
                    FilledButton.tonal(
                      onPressed: _loadingJ || _caseIdJ == null ? null : _loadCaseFinancialSummary,
                      child: const Text('عرض الملخص'),
                    ),
                  ],
                ),
                if (_caseFinSum != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('تحصيلات: ${_moneyJ.format(_caseFinSum!.sumIncome)}')),
                      Chip(label: Text('مصروفات قضية: ${_moneyJ.format(_caseFinSum!.sumExpense)}')),
                      Chip(label: Text('صافي نقد القضية: ${_moneyJ.format(_caseFinSum!.netCashCase)}')),
                      if (_caseFinSum!.feeTotal != null)
                        Chip(label: Text('متفق أتعاب: ${_moneyJ.format(_caseFinSum!.feeTotal!)}')),
                      if (_caseFinSum!.remainingFromFee != null)
                        Chip(label: Text('متبقي أتعاب: ${_moneyJ.format(_caseFinSum!.remainingFromFee!)}')),
                      Chip(label: Text('عهدة معتمدة: ${_moneyJ.format(_caseFinSum!.custodySpendsApproved)}')),
                      Chip(label: Text('عهدة معلقة: ${_moneyJ.format(_caseFinSum!.custodySpendsPending)}')),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 12),
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
                      onSelected: (v) async {
                        setState(() {
                          _clientId = v;
                          _clientReport = null;
                          _caseIdJ = null;
                          _caseFinSum = null;
                          _casesForJ = const [];
                        });
                        if (v != null) await _loadCasesForJ(v);
                      },
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
                const SizedBox(height: 16),
                const _FinanceAuditLogSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _jLine(BuildContext context, String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Text(
            '${_moneyJ.format(amount)} ج.م',
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FinanceAuditLogSection extends StatefulWidget {
  const _FinanceAuditLogSection();

  @override
  State<_FinanceAuditLogSection> createState() => _FinanceAuditLogSectionState();
}

class _FinanceAuditLogSectionState extends State<_FinanceAuditLogSection> {
  final _permApi = PermissionsApi();
  final _financeApi = FinanceApi();
  late final Future<UserPermissionsDto> _permFuture = _permApi.myPermissions();
  List<FinanceAuditLogDto>? _logs;
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _financeApi.financeAuditLog(limit: 150);
      if (!mounted) return;
      setState(() => _logs = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return FutureBuilder<UserPermissionsDto>(
      future: _permFuture,
      builder: (context, snap) {
        final perms = snap.data?.permissions ?? const [];
        if (!perms.contains('finance.audit.read')) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'سجل التدقيق المالي',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'آخر العمليات المسجّلة: معاملات قضايا، مصروفات مكتب، صرف نثرية، اعتماد/رفض عهد.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: _loading ? null : _load,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تحديث السجل'),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))),
                ],
              ],
            ),
            if (_logs != null && _logs!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ListView.separated(
                  itemCount: _logs!.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, i) {
                    final r = _logs![i];
                    return ListTile(
                      dense: true,
                      title: Text(r.actionKey, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(
                        '${df.format(r.createdAt.toLocal())} · ${r.entityType}${r.entityId != null ? ' #${r.entityId}' : ''}'
                        '${r.caseId != null ? ' · قضية ${r.caseId}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_logs != null && _logs!.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('لا توجد سجلات بعد.'),
              ),
          ],
        );
      },
    );
  }
}
