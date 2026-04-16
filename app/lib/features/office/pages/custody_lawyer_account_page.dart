import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/custody_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';

/// تفاصيل عهدة محامٍ (أدمن) — نفس أسلوب صفحة الحسابات مع بطاقات ملونة وجدول مصروفات.
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
    final caseTitles = {for (final c in cases) c.id: c.title};
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
      caseTitles: caseTitles,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _addAdvance() async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة سلفة / تعزيز عهدة'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السلفة')));
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

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabel(status), style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
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
        final name = data.user?.fullName ?? data.user?.email ?? 'محامٍ #${widget.userId}';
        final rep = data.report;
        final advances = rep?.advancesSum ?? 0;
        final spentApproved = rep?.approvedSpendsSum ?? 0;
        final balance = rep?.currentBalance ?? 0;

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
                      'عهدة المحامي — $name',
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
                    _CustodySummaryCard(
                      color: const Color(0xFF2563EB),
                      label: 'إجمالي العهدة',
                      value: '${money.format(advances)} ج.م',
                      subtitle: 'مجموع السلف والتعزيزات',
                    ),
                    _CustodySummaryCard(
                      color: const Color(0xFFDC2626),
                      label: 'إجمالي المصروف',
                      value: '${money.format(spentApproved)} ج.م',
                      subtitle: 'المصروفات المعتمدة',
                    ),
                    _CustodySummaryCard(
                      color: const Color(0xFF16A34A),
                      label: 'المتبقي',
                      value: '${money.format(balance)} ج.م',
                      subtitle: 'الرصيد الحالي',
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
              if (rep == null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'لا يوجد حساب عهدة مفعّل لهذا المحامي. أنشئ عهدة من تبويب العُهد.',
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
                      Text('حركة العهدة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      if (data.spends.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('لا توجد مصروفات مسجّلة')),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: (MediaQuery.sizeOf(context).width - 40).clamp(600, 1400),
                            ),
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(110),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(1.6),
                                3: FixedColumnWidth(100),
                                4: FixedColumnWidth(110),
                                5: FixedColumnWidth(140),
                              },
                              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade200)),
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: Colors.grey.shade50),
                                  children: const [
                                    _Th('التاريخ'),
                                    _Th('البيان'),
                                    _Th('القضية'),
                                    _Th('المبلغ'),
                                    _Th('النوع'),
                                    _Th('الأوامر'),
                                  ],
                                ),
                                ...data.spends.map((s) {
                                  final caseLabel = s.caseId == null
                                      ? '—'
                                      : (data.caseTitles[s.caseId!] ?? '#${s.caseId}');
                                  return TableRow(
                                    children: [
                                      _Td(Text(df.format(s.occurredAt.toLocal()))),
                                      _Td(Text(s.description ?? '—')),
                                      _Td(Text(caseLabel)),
                                      _Td(
                                        Text(
                                          money.format(s.amount),
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                      _Td(Align(alignment: AlignmentDirectional.centerStart, child: _statusChip(s.status))),
                                      _Td(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _SquareAct(
                                              color: Colors.cyan.shade100,
                                              iconColor: Colors.cyan.shade800,
                                              icon: Icons.receipt_long_outlined,
                                              onPressed: () => _viewReceipts(s.id),
                                            ),
                                            if (s.status == 'pending') ...[
                                              const SizedBox(width: 6),
                                              _SquareAct(
                                                color: Colors.green.shade100,
                                                iconColor: Colors.green.shade800,
                                                icon: Icons.check,
                                                onPressed: () => _approve(s.id),
                                              ),
                                              const SizedBox(width: 6),
                                              _SquareAct(
                                                color: Colors.red.shade100,
                                                iconColor: Colors.red.shade800,
                                                icon: Icons.close,
                                                onPressed: () => _reject(s.id),
                                              ),
                                            ],
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
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _Td extends StatelessWidget {
  const _Td(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: child,
    );
  }
}

class _SquareAct extends StatelessWidget {
  const _SquareAct({
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
    required this.caseTitles,
  });

  final OfficeUserDto? user;
  final CustodyReportItemDto? report;
  final List<CustodySpendDto> spends;
  final Map<int, String> caseTitles;
}

class _CustodySummaryCard extends StatelessWidget {
  const _CustodySummaryCard({
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
              Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
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
