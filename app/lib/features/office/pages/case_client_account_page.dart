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

  Future<void> _addTransaction(double? caseFeeTotal) async {
    final amountCtrl = TextEditingController();
    final agreedFeeCtrl = TextEditingController(
      text: caseFeeTotal != null ? caseFeeTotal.toStringAsFixed(2) : '',
    );
    final descCtrl = TextEditingController();
    String direction = 'income';
    DateTime occurred = DateTime.now();
    var mode = 'transaction';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('إضافة إلى الحساب'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'transaction', label: Text('عملية مالية')),
                      ButtonSegment(value: 'agreed_fee', label: Text('إجمالي الأتعاب المتفق عليها')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setLocal(() => mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'agreed_fee') ...[
                    Text(
                      caseFeeTotal == null
                          ? 'يُحدَّد المبلغ الكلي المتفق عليه للقضية. لن يُضاف سطر تحصيل في الجدول إلا إذا اخترت «عملية مالية».'
                          : 'أدخل الإجمالي الجديد المطلوب من العميل (يمكن زيادته أو تعديله). لا يُسجَّل تحصيل في الجدول إلا من «عملية مالية».',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (caseFeeTotal != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'الحالي: ${NumberFormat('#,##0.00', 'ar').format(caseFeeTotal)} ج.م',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  if (mode == 'transaction') ...[
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
                  ] else ...[
                    TextField(
                      controller: agreedFeeCtrl,
                      decoration: const InputDecoration(labelText: 'إجمالي الأتعاب المتفق عليها *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
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
      agreedFeeCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    if (mode == 'agreed_fee') {
      final rawFee = agreedFeeCtrl.text.trim().replaceAll(',', '.');
      final feeVal = double.tryParse(rawFee);
      amountCtrl.dispose();
      agreedFeeCtrl.dispose();
      descCtrl.dispose();
      if (feeVal == null || feeVal <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
        return;
      }
      try {
        await _casesApi.patchCase(caseId: widget.caseId, body: {'fee_total': feeVal});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إجمالي الأتعاب المتفق عليها')));
        _reload();
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }

    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amt = double.tryParse(raw);
    final desc = descCtrl.text.trim();
    amountCtrl.dispose();
    agreedFeeCtrl.dispose();
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
        final collections = allTx.where((t) => t.direction == 'income').fold<double>(0, (a, t) => a + t.amount);
        final expenses = allTx.where((t) => t.direction == 'expense').fold<double>(0, (a, t) => a + t.amount);
        final fee = c.feeTotal;
        // المتبقي من الأتعاب = المتفق عليه ناقص التحصيلات (دخل «أتعاب» فقط)، دون خصم المصروفات من رصيد الأتعاب.
        final remainingFromFee = fee == null ? null : (fee - collections);
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
                    onPressed: () => _addTransaction(c.feeTotal),
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
                  final w = constraints.maxWidth;
                  final cards = <Widget>[
                    _FinSummaryCard(
                      color: const Color(0xFF1E40AF),
                      label: 'إجمالي الأتعاب المتفق عليها',
                      value: fee == null ? '—' : '${money.format(fee)} ج.م',
                    ),
                    _FinSummaryCard(
                      color: const Color(0xFF16A34A),
                      label: 'إجمالي التحصيلات',
                      value: '${money.format(collections)} ج.م',
                    ),
                    _FinSummaryCard(
                      color: const Color(0xFFDC2626),
                      label: 'إجمالي المصروفات',
                      value: '${money.format(expenses)} ج.م',
                    ),
                    _FinSummaryCard(
                      color: const Color(0xFFD97706),
                      label: 'إجمالي المتبقي',
                      value: remainingFromFee == null ? '—' : '${money.format(remainingFromFee)} ج.م',
                      subtitle: fee == null ? null : 'المتفق عليه ناقص التحصيلات',
                    ),
                  ];
                  Widget rowPair(int a, int b) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[a]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[b]),
                      ],
                    );
                  }

                  if (w >= 1000) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }
                  if (w >= 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        rowPair(0, 1),
                        const SizedBox(height: 10),
                        rowPair(2, 3),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
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
                        _TransactionsList(
                          rows: rows,
                          caseDto: c,
                          money: money,
                          df: df,
                          onEdit: _editTransaction,
                          onDelete: _deleteTransaction,
                          caseRef: _caseRef(c),
                          goToCase: () => context.go('/o/$officeCode/cases/${c.id}'),
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

}

class _TransactionsList extends StatelessWidget {
  const _TransactionsList({
    required this.rows,
    required this.caseDto,
    required this.money,
    required this.df,
    required this.onEdit,
    required this.onDelete,
    required this.caseRef,
    required this.goToCase,
  });

  final List<CaseTransactionDto> rows;
  final CaseDto caseDto;
  final NumberFormat money;
  final DateFormat df;
  final void Function(CaseTransactionDto) onEdit;
  final void Function(CaseTransactionDto) onDelete;
  final String caseRef;
  final VoidCallback goToCase;

  static const _hStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 102, child: Text('التاريخ', style: _hStyle)),
              Expanded(flex: 26, child: Text('البيان', style: _hStyle)),
              Expanded(flex: 24, child: Text('القضية / الموكل', style: _hStyle)),
              SizedBox(width: 92, child: Text('المبلغ', style: _hStyle)),
              SizedBox(width: 104, child: Text('النوع', style: _hStyle)),
              SizedBox(width: 118, child: Text('الأوامر', style: _hStyle)),
            ],
          ),
        ),
        for (final t in rows) ...[
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 102, child: Text(df.format(t.occurredAt.toLocal()), style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 26,
                  child: Text(
                    t.description ?? '—',
                    softWrap: true,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      InkWell(
                        onTap: goToCase,
                        child: Text(
                          caseRef,
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(caseDto.clientName, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    money.format(t.amount),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.direction == 'income' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _TypeChip(income: t.direction == 'income'),
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SquareIconButton(
                        color: Colors.cyan.shade100,
                        iconColor: Colors.cyan.shade800,
                        icon: Icons.edit_outlined,
                        onPressed: () => onEdit(t),
                      ),
                      const SizedBox(width: 8),
                      _SquareIconButton(
                        color: Colors.red.shade100,
                        iconColor: Colors.red.shade800,
                        icon: Icons.delete_outline,
                        onPressed: () => onDelete(t),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
    final fill = Color.alphaBlend(color.withValues(alpha: 0.14), Colors.white);
    final borderTint = Color.alphaBlend(color.withValues(alpha: 0.35), Colors.grey.shade300);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 132),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderTint),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
        ),
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
