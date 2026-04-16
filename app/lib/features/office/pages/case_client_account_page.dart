import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/transactions_api.dart';

/// حساب موكل لقضية محددة — تخطيط وألوان قريبة من «الإدارة المالية» مع بطاقات ملخص وجدول عمليات.
class CaseClientAccountPage extends StatefulWidget {
  const CaseClientAccountPage({super.key, required this.caseId});

  final int caseId;

  @override
  State<CaseClientAccountPage> createState() => _CaseClientAccountPageState();
}

class _CaseClientAccountPageState extends State<CaseClientAccountPage> {
  final _casesApi = CasesApi();
  final _txApi = TransactionsApi();

  late Future<_CaseAccountData> _future = _load();

  String _filter = 'all'; // all | income | expense

  Future<_CaseAccountData> _load() async {
    final c = await _casesApi.get(widget.caseId);
    final txs = await _txApi.listForCase(widget.caseId);
    return _CaseAccountData(caseDto: c, transactions: txs);
  }

  void _reload() => setState(() => _future = _load());

  String _caseRef(CaseDto c) {
    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) return c.caseNumber!;
    return '${c.id}';
  }

  List<CaseTransactionDto> _filtered(List<CaseTransactionDto> all) {
    switch (_filter) {
      case 'income':
        return all.where((t) => t.direction == 'income').toList();
      case 'expense':
        return all.where((t) => t.direction == 'expense').toList();
      default:
        return List.of(all);
    }
  }

  Future<void> _addTransaction() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String direction = 'income';
    DateTime occurred = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('إضافة عملية مالية'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('أتعاب')),
                      ButtonSegment(value: 'expense', label: Text('مصروف')),
                    ],
                    selected: {direction},
                    onSelectionChanged: (s) => setLocal(() => direction = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'البيان (اختياري)'),
                  ),
                  ListTile(
                    title: Text(DateFormat('yyyy-MM-dd').format(occurred.toLocal())),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: occurred,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => occurred = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
            ],
          );
        },
      ),
    );
    if (ok != true) {
      amountCtrl.dispose();
      descCtrl.dispose();
      return;
    }
    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amt = double.tryParse(raw);
    final desc = descCtrl.text.trim();
    amountCtrl.dispose();
    descCtrl.dispose();
    if (amt == null || amt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    try {
      await _txApi.create(
        caseId: widget.caseId,
        direction: direction,
        amount: amt,
        description: desc.isEmpty ? null : desc,
        occurredAt: occurred,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل العملية')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editTransaction(CaseTransactionDto t) async {
    final amountCtrl = TextEditingController(text: t.amount.toStringAsFixed(2));
    final descCtrl = TextEditingController(text: t.description ?? '');
    String direction = t.direction;
    var occurred = t.occurredAt.toLocal();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('تعديل العملية'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'income', label: Text('أتعاب')),
                      ButtonSegment(value: 'expense', label: Text('مصروف')),
                    ],
                    selected: {direction},
                    onSelectionChanged: (s) => setLocal(() => direction = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'البيان'),
                  ),
                  ListTile(
                    title: Text(DateFormat('yyyy-MM-dd').format(occurred)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: occurred,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => occurred = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
            ],
          );
        },
      ),
    );
    if (ok != true) {
      amountCtrl.dispose();
      descCtrl.dispose();
      return;
    }
    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amt = double.tryParse(raw);
    final desc = descCtrl.text.trim();
    amountCtrl.dispose();
    descCtrl.dispose();
    if (amt == null || amt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    try {
      await _txApi.update(
        transactionId: t.id,
        direction: direction,
        amount: amt,
        description: desc.isEmpty ? null : desc,
        occurredAt: occurred,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التعديل')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteTransaction(CaseTransactionDto t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العملية؟'),
        content: Text('${t.amount.toStringAsFixed(2)} — ${t.description ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _txApi.delete(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    final money = NumberFormat('#,##0.00', 'ar');
    final df = DateFormat('yyyy-MM-dd');

    if (widget.caseId <= 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('قضية غير صالحة'),
            TextButton(onPressed: () => context.go('/o/$officeCode/accounts'), child: const Text('العودة')),
          ],
        ),
      );
    }

    return FutureBuilder<_CaseAccountData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('تعذر التحميل: ${snap.error}'),
                TextButton(onPressed: () => context.go('/o/$officeCode/accounts'), child: const Text('العودة')),
              ],
            ),
          );
        }
        final data = snap.data!;
        final c = data.caseDto;
        final allTx = data.transactions;
        final income = allTx.where((t) => t.direction == 'income').fold<double>(0, (a, t) => a + t.amount);
        final expense = allTx.where((t) => t.direction == 'expense').fold<double>(0, (a, t) => a + t.amount);
        final fee = c.feeTotal;
        final remaining = fee == null ? null : (fee - (income - expense));
        final rows = _filtered(allTx);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/o/$officeCode/accounts'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('العودة للحسابات'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _addTransaction,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة عملية مالية'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الإدارة المالية — ${_caseRef(c)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final cards = [
                    _FinSummaryCard(
                      color: const Color(0xFF16A34A),
                      label: 'إجمالي الأتعاب المحصلة',
                      value: '${money.format(income)} ج.م',
                    ),
                    _FinSummaryCard(
                      color: const Color(0xFFCA8A04),
                      label: 'المبلغ المتبقي',
                      value: remaining == null ? '—' : '${money.format(remaining)} ج.م',
                      subtitle: fee == null ? null : 'من إجمالي ${money.format(fee)} ج.م',
                    ),
                    _FinSummaryCard(
                      color: const Color(0xFFDC2626),
                      label: 'إجمالي المصروفات',
                      value: '${money.format(expense)} ج.م',
                    ),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        cards[i],
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: DropdownButton<String>(
                          value: _filter,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('جميع العمليات')),
                            DropdownMenuItem(value: 'income', child: Text('أتعاب فقط')),
                            DropdownMenuItem(value: 'expense', child: Text('مصروفات فقط')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _filter = v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('لا توجد عمليات')),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraintsMaxWidth(context)),
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(110),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(2),
                                3: FixedColumnWidth(100),
                                4: FixedColumnWidth(100),
                                5: FixedColumnWidth(100),
                              },
                              border: TableBorder(
                                horizontalInside: BorderSide(color: Colors.grey.shade200),
                              ),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade50),
                                  children: _tableCellsHeader(const [
                                    'التاريخ',
                                    'البيان',
                                    'القضية / الموكل',
                                    'المبلغ',
                                    'النوع',
                                    'الأوامر',
                                  ]),
                                ),
                                ...rows.map((t) {
                                  final isInc = t.direction == 'income';
                                  return TableRow(
                                    children: [
                                      _cellPadding(Text(df.format(t.occurredAt.toLocal()))),
                                      _cellPadding(Text(t.description ?? '—')),
                                      _cellPadding(
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            InkWell(
                                              onTap: () => context.go('/o/$officeCode/cases/${c.id}'),
                                              child: Text(
                                                _caseRef(c),
                                                style: TextStyle(
                                                  color: AppColors.primaryBlue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(c.clientName, style: TextStyle(color: Colors.grey.shade800)),
                                          ],
                                        ),
                                      ),
                                      _cellPadding(
                                        Text(
                                          money.format(t.amount),
                                          style: TextStyle(
                                            color: isInc ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      _cellPadding(
                                        Align(
                                          alignment: AlignmentDirectional.centerStart,
                                          child: _TypeChip(income: isInc),
                                        ),
                                      ),
                                      _cellPadding(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _SquareIconButton(
                                              color: Colors.cyan.shade100,
                                              iconColor: Colors.cyan.shade800,
                                              icon: Icons.edit_outlined,
                                              onPressed: () => _editTransaction(t),
                                            ),
                                            const SizedBox(width: 8),
                                            _SquareIconButton(
                                              color: Colors.red.shade100,
                                              iconColor: Colors.red.shade800,
                                              icon: Icons.delete_outline,
                                              onPressed: () => _deleteTransaction(t),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double constraintsMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w - 40).clamp(600, 1400);
  }

  List<Widget> _tableCellsHeader(List<String> labels) {
    return labels
        .map(
          (s) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        )
        .toList();
  }

  Widget _cellPadding(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: child,
    );
  }
}

class _CaseAccountData {
  const _CaseAccountData({required this.caseDto, required this.transactions});
  final CaseDto caseDto;
  final List<CaseTransactionDto> transactions;
}

class _FinSummaryCard extends StatelessWidget {
  const _FinSummaryCard({
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.income});
  final bool income;

  @override
  Widget build(BuildContext context) {
    if (income) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('أتعاب', style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 12)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('مصروفات', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}
