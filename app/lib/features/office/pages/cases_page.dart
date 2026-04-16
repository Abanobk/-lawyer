import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/api_client.dart';
import 'package:lawyer_app/data/api/case_files_api.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  final _casesApi = CasesApi();
  final _clientsApi = ClientsApi();
  final _officeApi = OfficeApi();
  final _filesApi = CaseFilesApi();

  late Future<_CasesData> _future = _load();

  Future<_CasesData> _load() async {
    final results = await Future.wait([
      _casesApi.list(),
      _clientsApi.list(),
      _officeApi.users(),
    ]);
    return _CasesData(
      cases: results[0] as List<CaseDto>,
      clients: results[1] as List<ClientDto>,
      users: results[2] as List<OfficeUserDto>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
  }

  Future<void> _openCreateDialog(_CasesData data) async {
    final res = await showDialog<_CreateCaseResult>(
      context: context,
      builder: (context) => _CreateCaseDialog(clients: data.clients, users: data.users),
    );
    if (res == null) return;

    try {
      final created = await _casesApi.create(
        clientId: res.clientId,
        title: res.title,
        kind: res.kind,
        court: res.court,
        caseNumber: res.caseNumber,
        caseYear: res.caseYear,
        firstHearingAt: res.firstHearingAt,
        feeTotal: res.feeTotal,
        primaryLawyerUserId: res.primaryLawyerUserId,
        firstSessionNumber: res.firstSessionNumber,
        firstSessionYear: res.firstSessionYear,
      );

      if (res.attachFile != null) {
        await _filesApi.upload(caseId: created.id, file: res.attachFile!);
      }
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة القضية')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _uploadForCase(int caseId) async {
    final res = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp'],
    );
    final files = res?.files;
    final file = (files == null || files.isEmpty) ? null : files.first;
    if (file == null) return;

    try {
      await _filesApi.upload(caseId: caseId, file: file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع الملف')));
    } on CaseFilesApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملف: $e')));
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
            Icon(Icons.work_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'إدارة القضايا',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            FutureBuilder<_CasesData>(
              future: _future,
              builder: (context, snap) {
                return FilledButton.icon(
                  onPressed: snap.hasData ? () => _openCreateDialog(snap.data!) : null,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة قضية جديدة'),
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: FutureBuilder<_CasesData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('تعذر تحميل القضايا: ${snap.error}'));
                }
                final cases = snap.data?.cases ?? const <CaseDto>[];
                if (cases.isEmpty) {
                  return const Center(child: Text('لا يوجد قضايا بعد'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الموكل')),
                      DataColumn(label: Text('نوع القضية')),
                      DataColumn(label: Text('المحكمة')),
                      DataColumn(label: Text('رقم/سنة')),
                      DataColumn(label: Text('أول جلسة')),
                      DataColumn(label: Text('المحامي')),
                      DataColumn(label: Text('الأتعاب')),
                      DataColumn(label: Text('مرفقات')),
                    ],
                    rows: cases
                        .map(
                          (c) => DataRow(
                            cells: [
                              DataCell(Text(c.clientName)),
                              DataCell(Text(_kindLabel(c.kind))),
                              DataCell(Text(c.court ?? '—')),
                              DataCell(Text(_numYear(c.caseNumber, c.caseYear))),
                              DataCell(Text(c.firstHearingAt == null ? '—' : df.format(c.firstHearingAt!.toLocal()))),
                              DataCell(Text(c.primaryLawyerEmail ?? '—')),
                              DataCell(Text(c.feeTotal == null ? '—' : c.feeTotal!.toStringAsFixed(2))),
                              DataCell(
                                TextButton.icon(
                                  onPressed: () => _uploadForCase(c.id),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('رفع ملف'),
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
}

class _CasesData {
  const _CasesData({required this.cases, required this.clients, required this.users});
  final List<CaseDto> cases;
  final List<ClientDto> clients;
  final List<OfficeUserDto> users;
}

class _CreateCaseResult {
  const _CreateCaseResult({
    required this.clientId,
    required this.title,
    required this.kind,
    this.court,
    this.caseNumber,
    this.caseYear,
    this.firstHearingAt,
    this.feeTotal,
    this.primaryLawyerUserId,
    this.firstSessionNumber,
    this.firstSessionYear,
    this.attachFile,
  });

  final int clientId;
  final String title;
  final String kind;
  final String? court;
  final String? caseNumber;
  final int? caseYear;
  final DateTime? firstHearingAt;
  final double? feeTotal;
  final int? primaryLawyerUserId;
  final String? firstSessionNumber;
  final int? firstSessionYear;
  final PlatformFile? attachFile;
}

class _CreateCaseDialog extends StatefulWidget {
  const _CreateCaseDialog({required this.clients, required this.users});

  final List<ClientDto> clients;
  final List<OfficeUserDto> users;

  @override
  State<_CreateCaseDialog> createState() => _CreateCaseDialogState();
}

class _CreateCaseDialogState extends State<_CreateCaseDialog> {
  final _title = TextEditingController();
  final _court = TextEditingController();
  final _caseNumber = TextEditingController();
  final _caseYear = TextEditingController();
  final _fee = TextEditingController();
  final _firstSessionNumber = TextEditingController();
  final _firstSessionYear = TextEditingController();

  int? _clientId;
  int? _lawyerId;
  String _kind = 'misdemeanor';
  DateTime? _firstHearing;
  PlatformFile? _pickedFile;

  @override
  void dispose() {
    _title.dispose();
    _court.dispose();
    _caseNumber.dispose();
    _caseYear.dispose();
    _fee.dispose();
    _firstSessionNumber.dispose();
    _firstSessionYear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة قضية'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownMenu<int>(
                initialSelection: _clientId,
                label: const Text('الموكل *'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: widget.clients
                    .map((c) => DropdownMenuEntry<int>(value: c.id, label: c.fullName))
                    .toList(),
                onSelected: (v) => setState(() => _clientId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان/وصف القضية *'),
              ),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                initialSelection: _kind,
                label: const Text('نوع القضية'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'misdemeanor', label: 'جنح'),
                  DropdownMenuEntry(value: 'felony', label: 'جنايات'),
                  DropdownMenuEntry(value: 'civil', label: 'مدني'),
                  DropdownMenuEntry(value: 'family', label: 'أسرة'),
                  DropdownMenuEntry(value: 'other', label: 'أخرى'),
                ],
                onSelected: (v) => setState(() => _kind = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _court,
                decoration: const InputDecoration(labelText: 'المحكمة (مثال: الجيزة / القاهرة)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caseNumber,
                      decoration: const InputDecoration(labelText: 'رقم القضية'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _caseYear,
                      decoration: const InputDecoration(labelText: 'السنة'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 5),
                          initialDate: _firstHearing ?? now,
                        );
                        if (picked != null) {
                          setState(() => _firstHearing = DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'ميعاد أول جلسة'),
                        child: Text(_firstHearing == null ? '—' : DateFormat('yyyy-MM-dd').format(_firstHearing!)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _fee,
                      decoration: const InputDecoration(labelText: 'الأتعاب'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownMenu<int>(
                initialSelection: _lawyerId,
                label: const Text('توجيه لمحامي المتابعة'),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries:
                    widget.users.map((u) => DropdownMenuEntry<int>(value: u.id, label: u.email)).toList(),
                onSelected: (v) => setState(() => _lawyerId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstSessionNumber,
                      decoration: const InputDecoration(labelText: 'رقم الجلسة (اختياري)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _firstSessionYear,
                      decoration: const InputDecoration(labelText: 'سنة الجلسة (اختياري)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'ملف القضية (اختياري)'),
                      child: Text(_pickedFile?.name ?? '—'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await FilePicker.pickFiles(
                        withData: true,
                        allowMultiple: false,
                        type: FileType.custom,
                        allowedExtensions: const ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg', 'webp'],
                      );
                      final file = (res?.files == null || res!.files.isEmpty) ? null : res.files.first;
                      setState(() => _pickedFile = file);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('اختيار ملف'),
                  ),
                  if (_pickedFile != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'إزالة',
                      onPressed: () => setState(() => _pickedFile = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            final cid = _clientId;
            final title = _title.text.trim();
            if (cid == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر الموكل')));
              return;
            }
            if (title.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب عنوان القضية')));
              return;
            }
            final year = int.tryParse(_caseYear.text.trim());
            final fee = double.tryParse(_fee.text.trim());
            final sYear = int.tryParse(_firstSessionYear.text.trim());

            Navigator.of(context).pop(
              _CreateCaseResult(
                clientId: cid,
                title: title,
                kind: _kind,
                court: _court.text.trim().isEmpty ? null : _court.text.trim(),
                caseNumber: _caseNumber.text.trim().isEmpty ? null : _caseNumber.text.trim(),
                caseYear: year,
                firstHearingAt: _firstHearing,
                feeTotal: fee,
                primaryLawyerUserId: _lawyerId,
                firstSessionNumber: _firstSessionNumber.text.trim().isEmpty ? null : _firstSessionNumber.text.trim(),
                firstSessionYear: sYear,
                attachFile: _pickedFile,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
