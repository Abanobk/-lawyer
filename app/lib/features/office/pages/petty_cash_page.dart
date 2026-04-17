import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/petty_cash_api.dart';

/// المرحلة ب — صناديق النثرية، تغذية، صرف بإيصال عند تجاوز سقف، تسوية جرد، تقرير فترة.
class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key});

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  final _api = PettyCashApi();
  final _money = NumberFormat('#,##0.00', 'ar');
  final _df = DateFormat('yyyy-MM-dd');

  List<PettyCashFundDto> _funds = const [];
  int? _fundId;
  List<PettyCashSpendDto> _spends = const [];
  PettyCashPeriodReportDto? _report;
  bool _loading = true;
  bool _busy = false;

  DateTime _reportFrom = DateTime.now().subtract(const Duration(days: 29));
  DateTime _reportTo = DateTime.now();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await _api.listFunds();
      if (!mounted) return;
      setState(() {
        _funds = list;
        if (_fundId == null && list.isNotEmpty) {
          _fundId = list.firstWhere((f) => f.isActive, orElse: () => list.first).id;
        } else if (_fundId != null && list.every((f) => f.id != _fundId)) {
          _fundId = list.isEmpty ? null : list.first.id;
        }
      });
      await _loadSpendsAndReport();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التحميل: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  PettyCashFundDto? get _selected {
    final id = _fundId;
    if (id == null) return null;
    for (final f in _funds) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> _loadSpendsAndReport() async {
    final id = _fundId;
    if (id == null) {
      setState(() {
        _spends = const [];
        _report = null;
      });
      return;
    }
    try {
      final spends = await _api.listSpends(id);
      final rep = await _api.periodReport(
        id,
        from: DateTime(_reportFrom.year, _reportFrom.month, _reportFrom.day),
        to: DateTime(_reportTo.year, _reportTo.month, _reportTo.day),
      );
      if (!mounted) return;
      setState(() {
        _spends = spends;
        _report = rep;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل حركات الصندوق: $e')));
    }
  }

  Future<void> _createFund() async {
    final ctrl = TextEditingController(text: 'صندوق النثرية الرئيسي');
    final thresh = TextEditingController(text: '500');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صندوق نثرية جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم الصندوق')),
            const SizedBox(height: 12),
            TextField(
              controller: thresh,
              decoration: const InputDecoration(
                labelText: 'سقف الإيصال (ج.م) — أعلى منه يصبح الإيصال إلزامياً (0 = اختياري دائماً)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      thresh.dispose();
      return;
    }
    final t = double.tryParse(thresh.text.trim().replaceAll(',', '.')) ?? 0;
    final name = ctrl.text.trim();
    ctrl.dispose();
    thresh.dispose();
    setState(() => _busy = true);
    try {
      final f = await _api.createFund(name: name, receiptRequiredAbove: t);
      if (!mounted) return;
      setState(() => _fundId = f.id);
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _topUp() async {
    final f = _selected;
    if (f == null) return;
    final amt = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغذية الصندوق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amt,
              decoration: const InputDecoration(labelText: 'المبلغ *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) {
      amt.dispose();
      notes.dispose();
      return;
    }
    final v = double.tryParse(amt.text.trim().replaceAll(',', '.'));
    final notesText = notes.text.trim();
    amt.dispose();
    notes.dispose();
    if (v == null || v <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.addTopUp(f.id, amount: v, notes: notesText.isEmpty ? null : notesText);
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settlement() async {
    final f = _selected;
    if (f == null) return;
    final amt = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسوية جرد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أدخل الفارق بعد الجرد: موجب إذا وجدت زيادة نقدية، سالب إذا عجز.'),
              const SizedBox(height: 12),
              TextField(
                controller: amt,
                decoration: const InputDecoration(labelText: 'المبلغ (+ أو −) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) {
      amt.dispose();
      notes.dispose();
      return;
    }
    final v = double.tryParse(amt.text.trim().replaceAll(',', '.'));
    final notesText = notes.text.trim();
    amt.dispose();
    notes.dispose();
    if (v == null || v == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً غير صفر')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.addSettlement(f.id, adjustmentAmount: v, notes: notesText.isEmpty ? null : notesText);
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _spend() async {
    final f = _selected;
    if (f == null) return;
    final amt = TextEditingController();
    final desc = TextEditingController();
    final caseIdCtrl = TextEditingController();
    PlatformFile? receipt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: const Text('صرف من النثرية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  f.receiptRequiredAbove > 0
                      ? 'إيصال إلزامي إذا المبلغ > ${_money.format(f.receiptRequiredAbove)} ج.م'
                      : 'الإيصال اختياري لهذا الصندوق.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amt,
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'الوصف')),
                TextField(
                  controller: caseIdCtrl,
                  decoration: const InputDecoration(labelText: 'رقم القضية (اختياري)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pick = await FilePicker.pickFiles(
                      withData: true,
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
                    );
                    if (pick != null && pick.files.isNotEmpty) setL(() => receipt = pick.files.first);
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(receipt == null ? 'إرفاق إيصال' : receipt!.name),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('صرف')),
          ],
        ),
      ),
    );
    if (ok != true) {
      amt.dispose();
      desc.dispose();
      caseIdCtrl.dispose();
      return;
    }
    final v = double.tryParse(amt.text.trim().replaceAll(',', '.'));
    final cid = int.tryParse(caseIdCtrl.text.trim());
    final descText = desc.text.trim();
    amt.dispose();
    desc.dispose();
    caseIdCtrl.dispose();
    if (v == null || v <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.createSpend(
        fundId: f.id,
        amount: v,
        description: descText.isEmpty ? null : descText,
        caseId: cid,
        receipt: receipt,
      );
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(child: Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())));
    }
    final f = _selected;
    final rep = _report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'النثرية — صرف يومي بسقف وإيصال عند الحاجة، مع تقرير تسوية للفترة.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                IconButton(onPressed: _busy ? null : _reload, icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            if (_funds.isEmpty)
              FilledButton.icon(
                onPressed: _busy ? null : _createFund,
                icon: const Icon(Icons.add),
                label: const Text('إنشاء صندوق نثرية'),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownMenu<int>(
                    width: 280,
                    label: const Text('الصندوق'),
                    initialSelection: _fundId,
                    dropdownMenuEntries: _funds.map((e) => DropdownMenuEntry(value: e.id, label: '${e.name} (${e.isActive ? 'نشط' : 'موقوف'})')).toList(),
                    onSelected: (v) async {
                      if (v == null) return;
                      setState(() => _fundId = v);
                      await _loadSpendsAndReport();
                    },
                  ),
                  if (f != null) ...[
                    Chip(
                      label: Text('الرصيد: ${_money.format(f.currentBalance)} ج.م'),
                      avatar: const Icon(Icons.savings_outlined, size: 18),
                    ),
                    FilledButton.tonal(onPressed: _busy ? null : _topUp, child: const Text('تغذية')),
                    FilledButton.tonal(onPressed: _busy ? null : _spend, child: const Text('صرف')),
                    OutlinedButton(onPressed: _busy ? null : _settlement, child: const Text('تسوية جرد')),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text('تقرير الفترة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _reportFrom,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setState(() => _reportFrom = p);
                    },
                    child: Text('من ${_df.format(_reportFrom)}'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _reportTo,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (p != null) setState(() => _reportTo = p);
                    },
                    child: Text('إلى ${_df.format(_reportTo)}'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _busy || f == null ? null : _loadSpendsAndReport, child: const Text('تحديث التقرير')),
                ],
              ),
              if (rep != null && f != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _repChip(context, 'رصيد افتتاحي (محسوب)', rep.openingBalance),
                    _repChip(context, 'تغذية', rep.sumTopUps),
                    _repChip(context, 'صرف', rep.sumSpends),
                    _repChip(context, 'تسويات', rep.sumSettlements),
                    _repChip(context, 'صافي الفترة', rep.netChange),
                    _repChip(context, 'رصيد ختامي (محسوب)', rep.closingBalanceImplied),
                    _repChip(context, 'رصيد النظام حالياً', rep.currentBalance),
                  ],
                ),
                if ((rep.closingBalanceImplied - rep.currentBalance).abs() > 0.009)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'ملاحظة: اختلاف بسيط بين الرصيد المحسوب و«رصيد النظام» يعني وجود حركات خارج الفترة المعروضة أو بعد تاريخ نهاية التقرير.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.tertiary),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text('آخر عمليات الصرف', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(
                child: _spends.isEmpty
                    ? const Center(child: Text('لا توجد صرفيات بعد'))
                    : ListView.separated(
                        itemCount: _spends.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final s = _spends[i];
                          return ListTile(
                            title: Text('${_money.format(s.amount)} ج.م — ${s.description ?? '—'}'),
                            subtitle: Text('${_df.format(s.occurredAt.toLocal())}${s.caseId != null ? ' — قضية ${s.caseId}' : ''}'),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _repChip(BuildContext context, String label, double value) {
    return Chip(
      label: Text('$label: ${_money.format(value)}'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
