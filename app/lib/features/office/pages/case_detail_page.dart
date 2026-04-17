import 'dart:js_interop';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/case_files_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';
import 'package:lawyer_app/data/api/transactions_api.dart';
import 'package:web/web.dart' as web;

class CaseDetailPage extends StatefulWidget {
  const CaseDetailPage({super.key, required this.caseId});

  final int caseId;

  @override
  State<CaseDetailPage> createState() => _CaseDetailPageState();
}

class _CaseDetailPageState extends State<CaseDetailPage> {
  final _casesApi = CasesApi();
  final _clientsApi = ClientsApi();
  final _sessionsApi = SessionsApi();
  final _transactionsApi = TransactionsApi();
  final _filesApi = CaseFilesApi();
  final _meApi = MeApi();
  final _permApi = PermissionsApi();

  late Future<_CaseDetailData> _future = _load();

  Future<_CaseDetailData> _load() async {
    final results = await Future.wait([
      _casesApi.get(widget.caseId),
      _clientsApi.list(),
      _sessionsApi.list(),
      _transactionsApi.listForCase(widget.caseId),
      _filesApi.list(caseId: widget.caseId),
      _meApi.me(),
      _permApi.myPermissions(),
    ]);
    final c = results[0] as CaseDto;
    final clients = results[1] as List<ClientDto>;
    final sessions = (results[2] as List<SessionDto>).where((s) => s.caseId == widget.caseId).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final txs = results[3] as List<CaseTransactionDto>;
    final files = results[4] as List<CaseFileDto>;
    final me = results[5] as MeDto;
    final perms = results[6] as UserPermissionsDto;
    final canViewAccounts = perms.permissions.contains('accounts.read');
    ClientDto? client;
    for (final cl in clients) {
      if (cl.id == c.clientId) {
        client = cl;
        break;
      }
    }
    return _CaseDetailData(
      caseDto: c,
      client: client,
      sessions: sessions,
      transactions: txs,
      files: files,
      me: me,
      canViewAccounts: canViewAccounts,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _webDownload(CaseFileDto f) async {
    if (!kIsWeb) return;
    final res = await _filesApi.download(fileId: f.id);
    final bytesPart = res.$1.toJS as web.BlobPart;
    final parts = <web.BlobPart>[bytesPart].toJS;
    final blob = web.Blob(parts, web.BlobPropertyBag(type: res.$3));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = res.$2;
    a.click();
    web.URL.revokeObjectURL(url);
  }

  Future<void> _uploadFile() async {
    final res = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp'],
    );
    final file = (res?.files == null || res!.files.isEmpty) ? null : res.files.first;
    if (file == null) return;
    try {
      await _filesApi.upload(caseId: widget.caseId, file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الملف')));
      _reload();
    } on CaseFilesApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملف: $e')));
    }
  }

  Future<void> _deleteFile(CaseFileDto f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف؟'),
        content: Text(f.originalName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _filesApi.delete(fileId: f.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الملف')));
      _reload();
    } on CaseFilesApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addSession(_CaseDetailData data) async {
    if (data.me.role != 'office_owner') return;
    DateTime sessionDate = DateTime.now();
    final notesCtrl = TextEditingController();
    final feeAmountCtrl = TextEditingController();
    final feeNoteCtrl = TextEditingController();
    DateTime? feeDue;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('إضافة جلسة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(DateFormat('yyyy-MM-dd').format(sessionDate.toLocal())),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: sessionDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => sessionDate = picked);
                    },
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Text('تذكير مالي (اختياري)', style: Theme.of(context).textTheme.titleSmall),
                  TextField(
                    controller: feeAmountCtrl,
                    decoration: const InputDecoration(labelText: 'مبلغ متوقع / مستحق'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  ListTile(
                    title: Text(feeDue == null ? 'موعد متابعة —' : DateFormat('yyyy-MM-dd').format(feeDue!)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: feeDue ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => feeDue = DateTime(picked.year, picked.month, picked.day));
                    },
                  ),
                  TextField(
                    controller: feeNoteCtrl,
                    decoration: const InputDecoration(labelText: 'ملاحظة مالية'),
                    maxLines: 2,
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
      notesCtrl.dispose();
      feeAmountCtrl.dispose();
      feeNoteCtrl.dispose();
      return;
    }
    final rawFee = feeAmountCtrl.text.trim().replaceAll(',', '.');
    final feeVal = rawFee.isEmpty ? null : double.tryParse(rawFee);
    final feeNote = feeNoteCtrl.text.trim().isEmpty ? null : feeNoteCtrl.text.trim();
    feeAmountCtrl.dispose();
    feeNoteCtrl.dispose();
    if (rawFee.isNotEmpty && feeVal == null) {
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ التذكير غير صالح')));
      return;
    }
    try {
      await _sessionsApi.create(
        caseId: widget.caseId,
        sessionDate: sessionDate,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        feeReminderAmount: feeVal,
        feeReminderDueAt: feeDue,
        feeReminderNote: feeNote,
      );
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الجلسة')));
      _reload();
    } on ApiException catch (e) {
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editSession(SessionDto s) async {
    var sessionDate = s.sessionDate.toLocal();
    final notesCtrl = TextEditingController(text: s.notes ?? '');
    final feeAmountCtrl = TextEditingController(
      text: s.feeReminderAmount != null ? s.feeReminderAmount!.toString() : '',
    );
    final feeNoteCtrl = TextEditingController(text: s.feeReminderNote ?? '');
    DateTime? feeDue = s.feeReminderDueAt?.toLocal();
    var feeDueTouched = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('تعديل الجلسة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(DateFormat('yyyy-MM-dd').format(sessionDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: sessionDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => sessionDate = picked);
                    },
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Text('تذكير مالي (اختياري)', style: Theme.of(context).textTheme.titleSmall),
                  TextField(
                    controller: feeAmountCtrl,
                    decoration: const InputDecoration(labelText: 'مبلغ متوقع / مستحق'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(feeDue == null ? 'موعد متابعة —' : DateFormat('yyyy-MM-dd').format(feeDue!)),
                          trailing: const Icon(Icons.event),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: feeDue ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setLocal(() {
                                feeDue = DateTime(picked.year, picked.month, picked.day);
                                feeDueTouched = true;
                              });
                            }
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () => setLocal(() {
                          feeDue = null;
                          feeDueTouched = true;
                        }),
                        child: const Text('مسح الموعد'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: feeNoteCtrl,
                    decoration: const InputDecoration(labelText: 'ملاحظة مالية'),
                    maxLines: 2,
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
      notesCtrl.dispose();
      feeAmountCtrl.dispose();
      feeNoteCtrl.dispose();
      return;
    }
    final rawFee = feeAmountCtrl.text.trim().replaceAll(',', '.');
    final feeVal = rawFee.isEmpty ? null : double.tryParse(rawFee);
    final feeNote = feeNoteCtrl.text.trim().isEmpty ? null : feeNoteCtrl.text.trim();
    feeAmountCtrl.dispose();
    feeNoteCtrl.dispose();
    if (rawFee.isNotEmpty && feeVal == null) {
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ التذكير غير صالح')));
      return;
    }
    try {
      await _sessionsApi.update(
        sessionId: s.id,
        sessionDate: sessionDate,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        patchFeeReminder: true,
        feeReminderAmount: feeVal,
        feeReminderDueAt: feeDueTouched && feeDue != null ? feeDue : null,
        feeReminderNote: feeNote,
        feeReminderDueCleared: feeDueTouched && feeDue == null,
      );
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الجلسة')));
      _reload();
    } catch (e) {
      notesCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعديل: $e')));
    }
  }

  Future<void> _deleteSession(SessionDto s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الجلسة؟'),
        content: Text(DateFormat('yyyy-MM-dd').format(s.sessionDate.toLocal())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sessionsApi.deleteSession(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الجلسة')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addPayment() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'أتعاب');
    DateTime occurred = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('إضافة دفعة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'النوع / الوصف'),
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
    final amount = double.tryParse(raw);
    final description = descCtrl.text.trim();
    amountCtrl.dispose();
    descCtrl.dispose();
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ غير صالح')));
      return;
    }
    try {
      await _transactionsApi.create(
        caseId: widget.caseId,
        direction: 'income',
        amount: amount,
        description: description.isEmpty ? null : description,
        occurredAt: occurred,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الدفعة')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _caseRef(CaseDto c) {
    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) return c.caseNumber!;
    return '${c.id}';
  }

  String _kindLabel(String v) {
    switch (v) {
      case 'misdemeanor':
        return 'جنح';
      case 'felony':
        return 'جنايات';
      case 'civil':
        return 'مدني';
      case 'family':
        return 'أسرة';
      default:
        return 'أخرى';
    }
  }

  String _lawyerShort(CaseDto c) {
    final e = c.primaryLawyerEmail;
    if (e == null || e.isEmpty) return '—';
    final at = e.indexOf('@');
    if (at > 0) return e.substring(0, at);
    return e;
  }

  String _txTypeLabel(CaseTransactionDto t) {
    if (t.description != null && t.description!.trim().isNotEmpty) return t.description!.trim();
    return t.direction == 'income' ? 'أتعاب' : 'مصروف';
  }

  @override
  Widget build(BuildContext context) {
    final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    final df = DateFormat('yyyy-MM-dd');
    final money = NumberFormat('#,##0.00', 'ar');

    return FutureBuilder<_CaseDetailData>(
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
                Text('تعذر تحميل القضية: ${snap.error}'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/o/$officeCode/cases'),
                  child: const Text('العودة للقضايا'),
                ),
              ],
            ),
          );
        }
        final d = snap.data!;
        final c = d.caseDto;
        final fee = c.feeTotal;
        final paidIn = d.transactions.where((t) => t.direction == 'income').fold<double>(0, (p, t) => p + t.amount);
        final paidOut = d.transactions.where((t) => t.direction == 'expense').fold<double>(0, (p, t) => p + t.amount);
        final netPaid = paidIn - paidOut;
        final remaining = fee != null ? fee - netPaid : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => context.go('/o/$officeCode/cases'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('العودة للقضايا'),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تفاصيل القضية: ${_caseRef(c)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _summaryRow(
                    wide: wide,
                    children: [
                      _SummaryCard(
                        accent: const Color(0xFF1E3A8A),
                        title: 'الموكل',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 18, color: Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(d.client?.phone ?? '—'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _SummaryCard(
                        accent: const Color(0xFF06B6D4),
                        title: 'المحكمة / النوع',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.court ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(_kindLabel(c.kind)),
                          ],
                        ),
                      ),
                      _SummaryCard(
                        accent: const Color(0xFF16A34A),
                        title: 'الوضع المالي',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (remaining != null)
                              Text(
                                'المتبقي: ${money.format(remaining)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                              )
                            else
                              const Text('لم يُحدد إجمالي الأتعاب'),
                            if (fee != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'المدفوع: ${money.format(netPaid)} من ${money.format(fee)}',
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                            if (d.canViewAccounts && officeCode.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => context.go('/o/$officeCode/accounts/case/${c.id}'),
                                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                    label: const Text('حساب القضية التفصيلي'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        context.go('/o/$officeCode/accounts?tab=summary&case_id=${c.id}'),
                                    icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                                    label: const Text('الملخص المالي للفترة'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      _SummaryCard(
                        accent: const Color(0xFFEAB308),
                        title: 'الحالة',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Chip(
                                label: Text(c.isActive ? 'مفتوحة' : 'مغلقة'),
                                backgroundColor: c.isActive ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                                side: BorderSide.none,
                                labelStyle: TextStyle(
                                  color: c.isActive ? const Color(0xFF166534) : Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('البدء: ${df.format(c.createdAt.toLocal())}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _sessionsSection(d, df, money),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _paymentsSection(d, df, money),
                        ),
                      ],
                    )
                  else ...[
                    _sessionsSection(d, df, money),
                    const SizedBox(height: 16),
                    _paymentsSection(d, df, money),
                  ],
                  const SizedBox(height: 24),
                  _filesSection(d),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRow({required bool wide, required List<Widget> children}) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }

  Widget _sessionsSection(_CaseDetailData d, DateFormat df, NumberFormat money) {
    final owner = d.me.role == 'office_owner';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'الجدول الزمني للجلسات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (owner)
                  FilledButton.icon(
                    onPressed: () => _addSession(d),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('إضافة جلسة'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (d.sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('لا توجد جلسات مسجّلة')),
              )
            else
              ...d.sessions.map((s) => _SessionTile(
                    session: s,
                    dateLabel: df.format(s.sessionDate.toLocal()),
                    lawyerLabel: _lawyerShort(d.caseDto),
                    owner: owner,
                    onEdit: () => _editSession(s),
                    onDelete: () => _deleteSession(s),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _paymentsSection(_CaseDetailData d, DateFormat df, NumberFormat money) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'سجل المدفوعات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (d.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('لا توجد مدفوعات')),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.1),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('النوع', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  ...d.transactions.map(
                    (t) => TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(money.format(t.amount)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(_txTypeLabel(t)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(df.format(t.occurredAt.toLocal())),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _filesSection(_CaseDetailData d) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.folder_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'المستندات والملفات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _uploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('رفع ملف'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (d.files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('لا توجد مرفقات')),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: d.files.map((f) {
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(f.originalName),
                      subtitle: Text('${(f.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تنزيل',
                            icon: const Icon(Icons.download),
                            onPressed: kIsWeb ? () => _webDownload(f) : null,
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                            onPressed: () => _deleteFile(f),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaseDetailData {
  const _CaseDetailData({
    required this.caseDto,
    required this.client,
    required this.sessions,
    required this.transactions,
    required this.files,
    required this.me,
    required this.canViewAccounts,
  });

  final CaseDto caseDto;
  final ClientDto? client;
  final List<SessionDto> sessions;
  final List<CaseTransactionDto> transactions;
  final List<CaseFileDto> files;
  final MeDto me;
  final bool canViewAccounts;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.accent,
    required this.title,
    required this.child,
  });

  final Color accent;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(
          start: BorderSide(color: accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.dateLabel,
    required this.lawyerLabel,
    required this.owner,
    required this.onEdit,
    required this.onDelete,
  });

  final SessionDto session;
  final String dateLabel;
  final String lawyerLabel;
  final bool owner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Container(width: 2, height: 72, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (owner) ...[
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.cyan.shade700, size: 20),
                          onPressed: onEdit,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                          onPressed: onDelete,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('المحامي: $lawyerLabel', style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                  ),
                  if (session.notes != null && session.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('ملاحظات: ${session.notes}', style: TextStyle(color: Colors.grey.shade800)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
