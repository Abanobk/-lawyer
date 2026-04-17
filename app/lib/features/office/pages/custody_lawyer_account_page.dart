import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/custody_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';

/// تفاصيل عهدة موظف — نفس منطق وتنسيق صفحة حساب القضية (بطاقات + جدول بعرض كامل).
class CustodyLawyerAccountPage extends StatefulWidget {
  const CustodyLawyerAccountPage({super.key, required this.userId});

  final int userId;

  @override
  State<CustodyLawyerAccountPage> createState() => _CustodyLawyerAccountPageState();
}

class _CustodyLawyerAccountPageState extends State<CustodyLawyerAccountPage> {
  final _reportsApi = ReportsApi();
  final _custodyApi = CustodyApi();
  final _officeApi = OfficeApi();
  final _casesApi = CasesApi();

  late Future<_CustodyLawyerData> _future = _load();

  /// all | pending | approved | rejected
  String _filter = 'all';

  Future<_CustodyLawyerData> _load() async {
    final results = await Future.wait([
      _officeApi.users(),
      _reportsApi.custody(userId: widget.userId),
      _custodyApi.listSpendsAdmin(),
      _casesApi.list(),
    ]);
    final users = results[0] as List<OfficeUserDto>;
    final reportList = results[1] as List<CustodyReportItemDto>;
    final spendsAll = results[2] as List<CustodySpendDto>;
    final cases = results[3] as List<CaseDto>;
    final report = reportList.isEmpty ? null : reportList.first;
    final spends = spendsAll.where((s) => s.userId == widget.userId).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final caseById = {for (final c in cases) c.id: c};
    OfficeUserDto? user;
    for (final u in users) {
      if (u.id == widget.userId) {
        user = u;
        break;
      }
    }
    return _CustodyLawyerData(
      user: user,
      report: report,
      spends: spends,
      caseById: caseById,
    );
  }

  void _reload() => setState(() => _future = _load());

  List<CustodySpendDto> _filtered(List<CustodySpendDto> all) {
    switch (_filter) {
      case 'pending':
        return all.where((s) => s.status == 'pending').toList();
      case 'approved':
        return all.where((s) => s.status == 'approved').toList();
      case 'rejected':
        return all.where((s) => s.status == 'rejected').toList();
      default:
        return List.of(all);
    }
  }

  Future<void> _addAdvance() async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة عملية مالية'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'المبلغ *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) {
      amountCtrl.dispose();
      notesCtrl.dispose();
      return;
    }
    final amt = double.tryParse(amountCtrl.text.trim().replaceAll(',', '.'));
    final notes = notesCtrl.text.trim();
    amountCtrl.dispose();
    notesCtrl.dispose();
    if (amt == null || amt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    try {
      await _custodyApi.addAdvance(
        userId: widget.userId,
        amount: amt,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل العملية')));
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
      builder: (context) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(controller: c, decoration: const InputDecoration(labelText: 'اختياري')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('رفض')),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await _custodyApi.rejectSpend(spendId, reason: reason.trim().isEmpty ? null : reason.trim());
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
        builder: (context) => AlertDialog(
          title: Text('إيصالات #$spendId'),
          content: SizedBox(
            width: 400,
            child: receipts.isEmpty
                ? const Text('لا توجد مرفقات')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: receipts.map((r) => ListTile(title: Text(r.originalName))).toList(),
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static String _caseRef(CaseDto? c) {
    if (c == null) return '—';
    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) return c.caseNumber!;
    return '${c.id}';
  }

  @override
  Widget build(BuildContext context) {
    final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    final money = NumberFormat('#,##0.00', 'ar');
    final df = DateFormat('yyyy-MM-dd');

    if (widget.userId <= 0) {
      return Center(child: TextButton(onPressed: () => context.go('/o/$officeCode/accounts?tab=custody'), child: const Text('العودة')));
    }

    return FutureBuilder<_CustodyLawyerData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('تعذر التحميل: ${snap.error}'),
                TextButton(onPressed: () => context.go('/o/$officeCode/accounts?tab=custody'), child: const Text('العودة')),
              ],
            ),
          );
        }
        final data = snap.data!;
        final name = data.user?.fullName ?? data.user?.email ?? 'موظف #${widget.userId}';
        final rep = data.report;
        final advances = rep?.advancesSum ?? 0;
        final spentApproved = rep?.approvedSpendsSum ?? 0;
        final balance = rep?.currentBalance ?? 0;
        final spendRows = _filtered(data.spends);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/o/$officeCode/accounts?tab=custody'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('العودة للعُهد'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _addAdvance,
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
                      'العُهد — $name',
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
                    _CustodyTintedSummaryCard(
                      color: const Color(0xFF1E40AF),
                      label: 'إجمالي العهدة',
                      value: '${money.format(advances)} ج.م',
                      subtitle: 'مجموع السلف والتعزيزات',
                    ),
                    _CustodyTintedSummaryCard(
                      color: const Color(0xFFDC2626),
                      label: 'إجمالي المصروفات',
                      value: '${money.format(spentApproved)} ج.م',
                      subtitle: 'المصروفات المعتمدة',
                    ),
                    _CustodyTintedSummaryCard(
                      color: const Color(0xFF16A34A),
                      label: 'إجمالي المتبقي',
                      value: '${money.format(balance)} ج.م',
                      subtitle: 'الرصيد الحالي',
                    ),
                  ];
                  if (w >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 10),
                            Expanded(child: cards[1]),
                          ],
                        ),
                        const SizedBox(height: 10),
                        cards[2],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        cards[i],
                      ],
                    ],
                  );
                },
              ),
              if (rep == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'لا يوجد حساب عهدة مفعّل لهذا الموظف. أنشئ عهدة من تبويب العُهد.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
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
                            DropdownMenuItem(value: 'pending', child: Text('معلق')),
                            DropdownMenuItem(value: 'approved', child: Text('معتمد')),
                            DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _filter = v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      if (spendRows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('لا توجد عمليات')),
                        )
                      else
                        _CustodySpendsRows(
                          spends: spendRows,
                          caseById: data.caseById,
                          money: money,
                          df: df,
                          caseRef: _caseRef,
                          onOpenCase: (caseId) => context.go('/o/$officeCode/cases/$caseId'),
                          onReceipts: _viewReceipts,
                          onApprove: _approve,
                          onReject: _reject,
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

class _CustodySpendsRows extends StatelessWidget {
  const _CustodySpendsRows({
    required this.spends,
    required this.caseById,
    required this.money,
    required this.df,
    required this.caseRef,
    required this.onOpenCase,
    required this.onReceipts,
    required this.onApprove,
    required this.onReject,
  });

  final List<CustodySpendDto> spends;
  final Map<int, CaseDto> caseById;
  final NumberFormat money;
  final DateFormat df;
  final String Function(CaseDto?) caseRef;
  final void Function(int caseId) onOpenCase;
  final Future<void> Function(int spendId) onReceipts;
  final Future<void> Function(int spendId) onApprove;
  final Future<void> Function(int spendId) onReject;

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
        for (final s in spends) ...[
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 102, child: Text(df.format(s.occurredAt.toLocal()), style: const TextStyle(fontSize: 13))),
                Expanded(
                  flex: 26,
                  child: Text(
                    s.description ?? '—',
                    softWrap: true,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: _caseClientCell(s),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    money.format(s.amount),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                SizedBox(
                  width: 104,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _CustodyStatusChip(status: s.status),
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CustodySquareIconButton(
                        color: Colors.cyan.shade100,
                        iconColor: Colors.cyan.shade800,
                        icon: Icons.receipt_long_outlined,
                        onPressed: () => onReceipts(s.id),
                      ),
                      if (s.status == 'pending') ...[
                        const SizedBox(width: 6),
                        _CustodySquareIconButton(
                          color: Colors.green.shade100,
                          iconColor: Colors.green.shade800,
                          icon: Icons.check,
                          onPressed: () => onApprove(s.id),
                        ),
                        const SizedBox(width: 6),
                        _CustodySquareIconButton(
                          color: Colors.red.shade100,
                          iconColor: Colors.red.shade800,
                          icon: Icons.close,
                          onPressed: () => onReject(s.id),
                        ),
                      ],
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

  Widget _caseClientCell(CustodySpendDto s) {
    final cid = s.caseId;
    final c = cid == null ? null : caseById[cid];
    if (c == null) {
      return Text(cid == null ? '—' : 'قضية #$cid', style: TextStyle(color: Colors.grey.shade800, fontSize: 13));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        InkWell(
          onTap: () => onOpenCase(c.id),
          child: Text(
            caseRef(c),
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        Text(c.clientName, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
      ],
    );
  }
}

class _CustodyStatusChip extends StatelessWidget {
  const _CustodyStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'معتمد';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'مرفوض';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'معلق';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _CustodySquareIconButton extends StatelessWidget {
  const _CustodySquareIconButton({
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

class _CustodyLawyerData {
  const _CustodyLawyerData({
    required this.user,
    required this.report,
    required this.spends,
    required this.caseById,
  });

  final OfficeUserDto? user;
  final CustodyReportItemDto? report;
  final List<CustodySpendDto> spends;
  final Map<int, CaseDto> caseById;
}

/// نفس أسلوب `_FinSummaryCard` في صفحة حساب القضية.
class _CustodyTintedSummaryCard extends StatelessWidget {
  const _CustodyTintedSummaryCard({
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
