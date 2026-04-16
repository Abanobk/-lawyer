import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _api = SessionsApi();
  final _meApi = MeApi();
  late Future<List<SessionDto>> _future = _api.list();
  late Future<MeDto> _meFuture = _meApi.me();

  void _reload() => setState(() => _future = _api.list());

  void _reloadAll() => setState(() {
        _future = _api.list();
        _meFuture = _meApi.me();
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
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('الموكل')),
                          DataColumn(label: Text('القضية')),
                          DataColumn(label: Text('رقم/سنة')),
                          DataColumn(label: Text('إجراء')),
                        ],
                        rows: items
                            .map(
                              (s) => DataRow(
                                cells: [
                                  DataCell(Text(df.format(s.sessionDate.toLocal()))),
                                  DataCell(Text(s.clientName)),
                                  DataCell(Text(s.caseTitle)),
                                  DataCell(Text(_numYear(s.sessionNumber, s.sessionYear))),
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
}

class _SessionUpdateResult {
  const _SessionUpdateResult({
    this.sessionDate,
    this.sessionNumber,
    this.sessionYear,
    this.notes,
  });

  final DateTime? sessionDate;
  final String? sessionNumber;
  final int? sessionYear;
  final String? notes;
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

  @override
  void initState() {
    super.initState();
    _date = widget.session.sessionDate.toLocal();
    _roll.text = widget.session.sessionNumber ?? '';
    _year.text = widget.session.sessionYear?.toString() ?? '';
    _notes.text = widget.session.notes ?? '';
  }

  @override
  void dispose() {
    _roll.dispose();
    _year.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الجلسة'),
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
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
