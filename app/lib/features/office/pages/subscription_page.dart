import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/data/api/plans_api.dart';
import 'package:lawyer_app/data/api/subscription_api.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _plansApi = PlansApi();
  final _subApi = SubscriptionApi();
  final _filesApi = SubscriptionFilesApi();

  late final Future<List<PlanDto>> _plansFuture = _plansApi.list();
  late Future<List<PaymentProofDto>> _proofsFuture = _subApi.listPaymentProofs();

  int? _selectedPlanId;
  PlatformFile? _pickedFile;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    final f = (res?.files.isNotEmpty ?? false) ? res!.files.first : null;
    if (f == null) return;
    setState(() => _pickedFile = f);
  }

  Future<void> _openLink(String? link) async {
    if (link == null || link.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد رابط إنستاباي لهذه الباقة')));
      return;
    }
    final uri = Uri.tryParse(link.trim());
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط غير صالح')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  Future<void> _upload() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر باقة أولاً')));
      return;
    }
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر صورة التحويل')));
      return;
    }
    setState(() => _uploading = true);
    try {
      await _filesApi.uploadPaymentProof(
        planId: _selectedPlanId!,
        file: _pickedFile!,
        referenceCode: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      _reference.clear();
      _notes.clear();
      setState(() {
        _pickedFile = null;
        _proofsFuture = _subApi.listPaymentProofs();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع إثبات التحويل وسيتم مراجعته')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'تمت الموافقة';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }

  Future<void> _viewProof(PaymentProofDto p) async {
    try {
      final (bytes, contentType) = await _filesApi.downloadPaymentProof(p.id);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) {
          final isPdf = (contentType ?? '').contains('pdf');
          return AlertDialog(
            title: Text('إثبات التحويل #${p.id}'),
            content: SizedBox(
              width: AppLayout.isWebDesktop(context) ? 900 : 360,
              child: isPdf
                  ? const Text('تم تنزيل ملف PDF. فتحه مباشرة غير مدعوم هنا.')
                  : Image.memory(bytes, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر عرض الإثبات: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: AppLayout.isWebDesktop(context) ? 2 : 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<PlanDto>>(
                future: _plansFuture,
                builder: (context, snap) {
                  final plans = snap.data ?? const <PlanDto>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إدارة الاشتراك', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('اختر باقة ثم افتح رابط إنستاباي وارفع صورة التحويل للمراجعة.'),
                      const SizedBox(height: 16),
                      if (snap.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (snap.hasError)
                        Text('تعذر تحميل الباقات: ${snap.error}')
                      else if (plans.isEmpty)
                        const Text('لا توجد باقات متاحة حالياً')
                      else
                        DropdownButtonFormField<int>(
                          initialValue: _selectedPlanId,
                          decoration: const InputDecoration(labelText: 'الباقة'),
                          items: plans
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name} — ${(p.priceCents / 100).toStringAsFixed(2)}'),
                                ),
                              )
                              .toList(),
                          onChanged: _uploading ? null : (v) => setState(() => _selectedPlanId = v),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _uploading
                            ? null
                            : (_selectedPlanId == null || plans.isEmpty)
                                ? null
                                : () {
                                    final p = plans.firstWhere((e) => e.id == _selectedPlanId, orElse: () => plans.first);
                                    _openLink(p.instapayLink);
                                  },
                        child: const Text('فتح إنستاباي'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_pickedFile == null ? 'اختيار صورة التحويل' : _pickedFile!.name),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reference,
                        enabled: !_uploading,
                        decoration: const InputDecoration(labelText: 'رقم مرجعي/ملاحظة على التحويل (اختياري)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notes,
                        enabled: !_uploading,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _uploading ? null : _upload,
                        child: _uploading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('رفع الإثبات'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (AppLayout.isWebDesktop(context)) const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<PaymentProofDto>>(
                future: _proofsFuture,
                builder: (context, snap) {
                  final proofs = snap.data ?? const <PaymentProofDto>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إثباتات التحويل', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (snap.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (snap.hasError)
                        Text('تعذر تحميل الإثباتات: ${snap.error}')
                      else if (proofs.isEmpty)
                        const Text('لم يتم رفع أي إثباتات بعد')
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: proofs.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final p = proofs[i];
                              final color = _statusColor(p.status);
                              return ListTile(
                                title: Text('إثبات #${p.id}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الحالة: ${_statusLabel(p.status)}'),
                                    if ((p.decisionNotes ?? '').isNotEmpty) Text('ملاحظة الإدارة: ${p.decisionNotes}'),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: color.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(_statusLabel(p.status), style: TextStyle(color: color)),
                                ),
                                onTap: () => _viewProof(p),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

