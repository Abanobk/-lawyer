import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _api = SessionsApi();
  final _meApi = MeApi();
  final _permApi = PermissionsApi();
  late Future<List<SessionDto>> _future = _api.list();
  late Future<MeDto> _meFuture = _meApi.me();
  late Future<UserPermissionsDto> _permsFuture = _permApi.myPermissions();

  void _reload() => setState(() => _future = _api.list());

  void _reloadAll() => setState(() {
        _future = _api.list();
        _meFuture = _meApi.me();
        _permsFuture = _permApi.myPermissions();
      });

  Future<void> _reschedule(SessionDto s) async {
    final res = await showDialog<_SessionUpdateResult>(
      context: context,
      builder: (context) => _RescheduleDialog(session: s),
    );
    if (res == null) return;
    try {
      await _api.update(
        sessionId: s.id,
        sessionDate: res.sessionDate,
        sessionNumber: res.sessionNumber,
        sessionYear: res.sessionYear,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل موعد الجلسة')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل ترحيل الجلسة: $e')));
    }
  }

  Future<void> _edit(SessionDto s) async {
    final res = await showDialog<_SessionUpdateResult>(
      context: context,
      builder: (context) => _EditSessionDialog(session: s),
    );
    if (res == null) return;
    try {
      await _api.update(
        sessionId: s.id,
        sessionDate: res.sessionDate,
        sessionNumber: res.sessionNumber,
        sessionYear: res.sessionYear,
        notes: res.notes,
        patchFeeReminder: res.patchFeeReminder,
        feeReminderAmount: res.feeReminderAmount,
        feeReminderDueAt: res.feeReminderDueAt,
        feeReminderNote: res.feeReminderNote,
        feeReminderDueCleared: res.feeReminderDueCleared,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الجلسة')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تعديل الجلسة: $e')));
    }
  }

  Future<void> _setRoll(SessionDto s) async {
    final res = await showDialog<_SessionUpdateResult>(
      context: context,
      builder: (context) => _RollDialog(session: s),
    );
    if (res == null) return;
    try {
      await _api.update(
        sessionId: s.id,
        sessionNumber: res.sessionNumber,
        sessionYear: res.sessionYear,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ رقم الرول')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ الرول: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'الجلسات',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(onPressed: _reloadAll, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: FutureBuilder<MeDto>(
              future: _meFuture,
              builder: (context, meSnap) {
                final isAdmin = meSnap.data?.role == 'office_owner';
                return FutureBuilder<UserPermissionsDto>(
                  future: _permsFuture,
                  builder: (context, permSnap) {
                    final canViewAccounts = permSnap.data?.permissions.contains('accounts.read') ?? false;
                    final canViewSensitiveFinance =
                        permSnap.data?.permissions.contains('finance.sensitive.read') ?? false;
                    final canOpenCaseAccount = canViewAccounts;
                    return FutureBuilder<List<SessionDto>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(child: Text('تعذر تحميل الجلسات: ${snap.error}'));
                        }
                        final items = snap.data ?? const <SessionDto>[];
                        if (items.isEmpty) {
                          return const Center(child: Text('لا يوجد جلسات بعد'));
                        }
                        final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('الموكل')),
                              DataColumn(label: Text('القضية')),
                              DataColumn(label: Text('رقم/سنة')),
                              DataColumn(label: Text('تذكير مالي')),
                              DataColumn(label: Text('إجراء')),
                            ],
                            rows: items
                                .map(
                                  (s) => DataRow(
                                    cells: [
                                      DataCell(Text(df.format(s.sessionDate.toLocal()))),
                                      DataCell(Text(s.clientName)),
                                      DataCell(
                                        _SessionCaseLinks(
                                          caseId: s.caseId,
                                          caseTitle: s.caseTitle,
                                          officeCode: officeCode,
                                          canOpenAccount: canOpenCaseAccount,
                                        ),
                                      ),
                                      DataCell(Text(_numYear(s.sessionNumber, s.sessionYear))),
                                      DataCell(Text(
                                        _feeReminderHint(s, showAmount: canViewSensitiveFinance),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                      DataCell(
                                        isAdmin
                                            ? Wrap(
                                                spacing: 8,
                                                children: [
                                                  TextButton(onPressed: () => _edit(s), child: const Text('تعديل')),
                                                  TextButton(onPressed: () => _setRoll(s), child: const Text('رول')),
                                                  TextButton(onPressed: () => _reschedule(s), child: const Text('ترحيل')),
                                                ],
                                              )
                                            : const Text('—'),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _numYear(String? n, int? y) {
    if ((n == null || n.isEmpty) && y == null) return '—';
    if (n == null || n.isEmpty) return '—/$y';
    if (y == null) return '$n/—';
    return '$n/$y';
  }

  String _feeReminderHint(SessionDto s, {required bool showAmount}) {
    final parts = <String>[];
    if (showAmount && s.feeReminderAmount != null) {
      parts.add(NumberFormat('#,##0.##', 'ar').format(s.feeReminderAmount));
    }
    if (s.feeReminderDueAt != null) {
      parts.add('استحقاق ${DateFormat('yyyy-MM-dd').format(s.feeReminderDueAt!.toLocal())}');
    }
    if (s.feeReminderNote != null && s.feeReminderNote!.trim().isNotEmpty) {
      final t = s.feeReminderNote!.trim();
      parts.add(t.length > 40 ? '${t.substring(0, 40)}…' : t);
    }
    if (parts.isEmpty) return '—';
    return parts.join(' · ');
  }
}

class _SessionCaseLinks extends StatelessWidget {
  const _SessionCaseLinks({
    required this.caseId,
    required this.caseTitle,
    required this.officeCode,
    required this.canOpenAccount,
  });

  final int caseId;
  final String caseTitle;
  final String officeCode;
  final bool canOpenAccount;

  @override
  Widget build(BuildContext context) {
    if (officeCode.isEmpty) {
      return Text(caseTitle, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Tooltip(
            message: 'تفاصيل القضية',
            child: InkWell(
              onTap: () => context.go('/o/$officeCode/cases/$caseId'),
              child: Text(
                caseTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        if (canOpenAccount)
          IconButton(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 20, color: theme.colorScheme.primary),
            tooltip: 'حساب القضية التفصيلي',
            onPressed: () => context.go('/o/$officeCode/accounts/case/$caseId'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }
}

class _SessionUpdateResult {
  const _SessionUpdateResult({
    this.sessionDate,
    this.sessionNumber,
    this.sessionYear,
    this.notes,
    this.patchFeeReminder = false,
    this.feeReminderAmount,
    this.feeReminderDueAt,
    this.feeReminderNote,
    this.feeReminderDueCleared = false,
  });

  final DateTime? sessionDate;
  final String? sessionNumber;
  final int? sessionYear;
  final String? notes;
  final bool patchFeeReminder;
  final double? feeReminderAmount;
  final DateTime? feeReminderDueAt;
  final String? feeReminderNote;
  final bool feeReminderDueCleared;
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.session});
  final SessionDto session;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  DateTime? _date;
  final _roll = TextEditingController();
  final _year = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.session.sessionDate.toLocal();
    _roll.text = widget.session.sessionNumber ?? '';
    _year.text = widget.session.sessionYear?.toString() ?? '';
  }

  @override
  void dispose() {
    _roll.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ترحيل جلسة'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 5),
                  initialDate: _date ?? now,
                );
                if (picked != null) {
                  setState(() => _date = DateTime(picked.year, picked.month, picked.day));
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'التاريخ الجديد'),
                child: Text(_date == null ? '—' : DateFormat('yyyy-MM-dd').format(_date!)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roll,
              decoration: const InputDecoration(labelText: 'رقم الرول (اختياري)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              decoration: const InputDecoration(labelText: 'سنة الرول (اختياري)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _SessionUpdateResult(
                sessionDate: _date,
                sessionNumber: _roll.text.trim().isEmpty ? null : _roll.text.trim(),
                sessionYear: int.tryParse(_year.text.trim()),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _RollDialog extends StatefulWidget {
  const _RollDialog({required this.session});
  final SessionDto session;

  @override
  State<_RollDialog> createState() => _RollDialogState();
}

class _RollDialogState extends State<_RollDialog> {
  final _roll = TextEditingController();
  final _year = TextEditingController();

  @override
  void initState() {
    super.initState();
    _roll.text = widget.session.sessionNumber ?? '';
    _year.text = widget.session.sessionYear?.toString() ?? '';
  }

  @override
  void dispose() {
    _roll.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تسجيل رقم الرول'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _roll, decoration: const InputDecoration(labelText: 'رقم الرول')),
            const SizedBox(height: 12),
            TextField(
              controller: _year,
              decoration: const InputDecoration(labelText: 'سنة الرول'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _SessionUpdateResult(
                sessionNumber: _roll.text.trim().isEmpty ? null : _roll.text.trim(),
                sessionYear: int.tryParse(_year.text.trim()),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _EditSessionDialog extends StatefulWidget {
  const _EditSessionDialog({required this.session});
  final SessionDto session;

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  DateTime? _date;
  final _roll = TextEditingController();
  final _year = TextEditingController();
  final _notes = TextEditingController();
  final _feeAmount = TextEditingController();
  final _feeNote = TextEditingController();
  DateTime? _feeDue;
  bool _feeDueTouched = false;

  @override
  void initState() {
    super.initState();
    _date = widget.session.sessionDate.toLocal();
    _roll.text = widget.session.sessionNumber ?? '';
    _year.text = widget.session.sessionYear?.toString() ?? '';
    _notes.text = widget.session.notes ?? '';
    if (widget.session.feeReminderAmount != null) {
      _feeAmount.text = widget.session.feeReminderAmount!.toString();
    }
    _feeNote.text = widget.session.feeReminderNote ?? '';
    _feeDue = widget.session.feeReminderDueAt?.toLocal();
  }

  @override
  void dispose() {
    _roll.dispose();
    _year.dispose();
    _notes.dispose();
    _feeAmount.dispose();
    _feeNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الجلسة'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 5),
                    initialDate: _date ?? now,
                  );
                  if (picked != null) {
                    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'التاريخ'),
                  child: Text(_date == null ? '—' : DateFormat('yyyy-MM-dd').format(_date!)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _roll, decoration: const InputDecoration(labelText: 'رقم الرول')),
              const SizedBox(height: 12),
              TextField(
                controller: _year,
                decoration: const InputDecoration(labelText: 'سنة الرول'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(controller: _notes, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 3),
              const SizedBox(height: 16),
              Text('تذكير مالي (اختياري)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _feeAmount,
                decoration: const InputDecoration(labelText: 'مبلغ مستحق / متوقع', hintText: 'اتركه فارغاً لمسح المبلغ'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'موعد متابعة/استحقاق'),
                      child: Text(_feeDue == null ? '—' : DateFormat('yyyy-MM-dd').format(_feeDue!)),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                        initialDate: _feeDue ?? now,
                      );
                      if (picked != null) {
                        setState(() {
                          _feeDue = DateTime(picked.year, picked.month, picked.day);
                          _feeDueTouched = true;
                        });
                      }
                    },
                    child: const Text('اختيار'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _feeDue = null;
                      _feeDueTouched = true;
                    }),
                    child: const Text('مسح'),
                  ),
                ],
              ),
              TextField(
                controller: _feeNote,
                decoration: const InputDecoration(labelText: 'ملاحظة مالية قصيرة'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final rawFee = _feeAmount.text.trim().replaceAll(',', '.');
            final feeVal = rawFee.isEmpty ? null : double.tryParse(rawFee);
            if (rawFee.isNotEmpty && feeVal == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ التذكير غير صالح')));
              return;
            }
            Navigator.of(context).pop(
              _SessionUpdateResult(
                sessionDate: _date,
                sessionNumber: _roll.text.trim().isEmpty ? null : _roll.text.trim(),
                sessionYear: int.tryParse(_year.text.trim()),
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                patchFeeReminder: true,
                feeReminderAmount: feeVal,
                feeReminderDueAt: _feeDueTouched && _feeDue != null ? _feeDue : null,
                feeReminderNote: _feeNote.text.trim().isEmpty ? null : _feeNote.text.trim(),
                feeReminderDueCleared: _feeDueTouched && _feeDue == null,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
