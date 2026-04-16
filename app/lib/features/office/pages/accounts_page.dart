import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('قريبًا: مصروفات المكتب ورفع إيصالاتها.'),
      ),
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
