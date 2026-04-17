import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lawyer_app/core/util/csv_download_web.dart';
import 'package:lawyer_app/core/util/office_data_export.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _meApi = MeApi();
  final _officeApi = OfficeApi();
  final _clientsApi = ClientsApi();
  final _casesApi = CasesApi();

  final _officeName = TextEditingController();
  final _phone = TextEditingController();
  final _contactEmail = TextEditingController();
  final _address = TextEditingController();
  final _fullName = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _exportBusy = false;
  bool _editing = false;
  String? _loginEmail;
  String _role = '';

  String _snapOfficeName = '';
  String _snapPhone = '';
  String _snapContactEmail = '';
  String _snapAddress = '';
  String _snapFullName = '';

  bool get _isOwner => _role == 'office_owner';

  bool get _officeFieldsEditable => _editing && _isOwner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_meApi.me(), _officeApi.myOffice()]);
      final me = results[0] as MeDto;
      final office = results[1] as OfficeDto;
      if (!mounted) return;
      _role = me.role;
      _loginEmail = me.email;
      _fullName.text = me.fullName ?? '';
      _officeName.text = office.name;
      _phone.text = office.phone ?? '';
      _contactEmail.text = office.contactEmail ?? '';
      _address.text = office.address ?? '';
      _captureSnapshot();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل الإعدادات')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _captureSnapshot() {
    _snapFullName = _fullName.text.trim();
    _snapOfficeName = _officeName.text.trim();
    _snapPhone = _phone.text.trim().replaceAll(' ', '');
    _snapContactEmail = _contactEmail.text.trim();
    _snapAddress = _address.text.trim();
  }

  void _restoreFromSnapshot() {
    _fullName.text = _snapFullName;
    _officeName.text = _snapOfficeName;
    _phone.text = _snapPhone;
    _contactEmail.text = _snapContactEmail;
    _address.text = _snapAddress;
  }

  @override
  void dispose() {
    _officeName.dispose();
    _phone.dispose();
    _contactEmail.dispose();
    _address.dispose();
    _fullName.dispose();
    super.dispose();
  }

  String? _validateForSave() {
    final name = _fullName.text.trim();
    if (name.length < 2) return 'اكتب اسمك الكامل للترحيب (حرفان على الأقل)';
    if (_isOwner) {
      final on = _officeName.text.trim();
      if (on.length < 2) return 'اسم المكتب يجب ألا يقل عن حرفين';
      final ph = _phone.text.trim().replaceAll(' ', '');
      if (ph.isNotEmpty && ph.length < 8) return 'رقم الموبايل غير صحيح';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validateForSave();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() => _saving = true);
    try {
      final name = _fullName.text.trim();
      if (name != _snapFullName) {
        await _meApi.patchProfile(fullName: name);
      }

      if (_isOwner) {
        final patch = <String, dynamic>{};
        final on = _officeName.text.trim();
        final ph = _phone.text.trim().replaceAll(' ', '');
        final ce = _contactEmail.text.trim();
        final ad = _address.text.trim();

        if (on != _snapOfficeName) patch['name'] = on;
        if (ph != _snapPhone) patch['phone'] = ph.isEmpty ? null : ph;
        if (ce != _snapContactEmail) patch['contact_email'] = ce.isEmpty ? null : ce;
        if (ad != _snapAddress) patch['address'] = ad.isEmpty ? null : ad;

        if (patch.isNotEmpty) {
          await _officeApi.patchOffice(patch);
        }
      }

      if (!mounted) return;
      _captureSnapshot();
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEdit() {
    setState(() {
      _editing = true;
    });
  }

  void _cancelEdit() {
    _restoreFromSnapshot();
    setState(() => _editing = false);
  }

  Future<void> _exportClientsCsv() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final list = await _clientsApi.list();
      final csv = clientsToCsv(list);
      if (kIsWeb) {
        downloadCsvWeb('clients_export.csv', csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنزيل ملف الموكلين')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تنزيل CSV مفعّل على نسخة الويب من التطبيق')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تصدير الموكلين: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _exportCasesCsv() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final list = await _casesApi.list();
      final csv = casesToCsv(list);
      if (kIsWeb) {
        downloadCsvWeb('cases_export.csv', csv);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنزيل ملف القضايا')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تنزيل CSV مفعّل على نسخة الويب من التطبيق')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تصدير القضايا: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'إعدادات المكتب',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _editing
                          ? 'عدّل الحقول ثم اضغط حفظ التغييرات.'
                          : 'عرض كل بيانات المكتب والحساب. اضغط «تعديل» للتعديل.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (!_isOwner) ...[
                      const SizedBox(height: 8),
                      Text(
                        'بيانات المكتب للقراءة فقط؛ يعدّلها مالك المكتب. يمكنك تعديل اسمك الظاهر في الترحيب.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('بيانات المكتب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _officeName,
                      enabled: _officeFieldsEditable,
                      decoration: const InputDecoration(
                        labelText: 'اسم المكتب / المؤسسة',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phone,
                      enabled: _officeFieldsEditable,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف / الموبايل',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contactEmail,
                      enabled: _officeFieldsEditable,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني للمكتب',
                        hintText: 'للتواصل — ليس بريد تسجيل الدخول',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _address,
                      enabled: _officeFieldsEditable,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 28),
                    Text('حسابي', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fullName,
                      enabled: _editing,
                      decoration: const InputDecoration(
                        labelText: 'اسمك الكامل (يظهر في الترحيب)',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني لتسجيل الدخول',
                        border: OutlineInputBorder(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_loginEmail ?? '—', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'نسخ احتياطي وتصدير',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تصدير بيانات الموكلين والقضايا كملف CSV (UTF-8) للاحتفاظ بها على جهازك. يُفضّل التنزيل من متصفح سطح المكتب.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _exportBusy ? null : _exportClientsCsv,
                          icon: _exportBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.file_download_outlined),
                          label: const Text('تصدير الموكلين CSV'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _exportBusy ? null : _exportCasesCsv,
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('تصدير القضايا CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_editing) ...[
                          OutlinedButton(
                            onPressed: _saving ? null : _cancelEdit,
                            child: const Text('إلغاء'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('حفظ التغييرات'),
                          ),
                        ] else
                          FilledButton(
                            onPressed: _startEdit,
                            child: const Text('تعديل'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
