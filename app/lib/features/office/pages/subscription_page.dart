import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/plan_offer_card.dart';
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
  final _filesApi = SubscriptionFilesApi();
  final _promoFilesApi = PlanPromoFilesApi();

  late final Future<List<PlanDto>> _plansFuture = _plansApi.list();

  int? _selectedPlanId;
  PlatformFile? _pickedFile;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _uploading = false;
  final Map<int, Future<Uint8List?>> _promoBytesFutures = {};

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
      setState(() => _pickedFile = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع إثبات التحويل وسيتم مراجعته')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _promoArea(PlanDto p) {
    final promoFuture = p.promoImagePath == null
        ? null
        : _promoBytesFutures.putIfAbsent(
            p.id,
            () async {
              try {
                final (bytes, _) = await _promoFilesApi.downloadPromo(p.id);
                return bytes;
              } catch (_) {
                return null;
              }
            },
          );
    if (promoFuture == null) {
      return Container(
        color: Colors.grey.withValues(alpha: 0.12),
        child: const Center(child: Icon(Icons.image_outlined, size: 48)),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: promoFuture,
      builder: (context, fs) {
        if (fs.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (!fs.hasData || fs.data == null) {
          return Container(
            color: Colors.grey.withValues(alpha: 0.12),
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
          );
        }
        return Image.memory(fs.data!, fit: BoxFit.cover, width: double.infinity);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<PlanDto>>(
        future: _plansFuture,
        builder: (context, snap) {
          final plans = snap.data ?? const <PlanDto>[];
          if (snap.connectionState == ConnectionState.done && _selectedPlanId == null && plans.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedPlanId = plans.first.id);
            });
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إدارة الاشتراك', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('اختر الباقة، ثم افتح إنستاباي من الزر. بعد الدفع ارفع صورة التحويل في الأسفل للمراجعة.'),
              const SizedBox(height: 16),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (snap.hasError)
                Text('تعذر تحميل الباقات: ${snap.error}')
              else if (plans.isEmpty)
                const Text('لا توجد باقات متاحة حالياً')
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final cross = w > 1100 ? 3 : (w > 640 ? 2 : 1);
                    final shown = plans.take(6).toList();
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: cross == 3 ? 0.58 : (cross == 2 ? 0.62 : 0.58),
                      ),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final p = shown[i];
                        final isSelected = p.id == _selectedPlanId;
                        final title = (p.packageName ?? '').trim().isNotEmpty ? p.packageName!.trim() : p.name;
                        return PlanOfferCard(
                          title: title,
                          optionName: p.name,
                          priceText: 'السعر: ${(p.priceCents / 100).toStringAsFixed(2)}',
                          durationText: 'المدة: ${p.durationDays} يوم',
                          maxUsersText: p.maxUsers != null ? 'حتى: ${p.maxUsers} مستخدم' : null,
                          permCountText: p.allowedPermKeys != null ? 'عدد الصلاحيات: ${p.allowedPermKeys!.length}' : null,
                          packageKeyText: p.packageKey,
                          footerHint: 'بعد الدفع استخدم زر «اشترِ الآن» لفتح إنستاباي، ثم ارفع الإثبات أسفل الصفحة.',
                          image: _promoArea(p),
                          selected: isSelected,
                          footer: FilledButton(
                            onPressed: _uploading || p.instapayLink == null
                                ? null
                                : () {
                                    setState(() => _selectedPlanId = p.id);
                                    _openLink(p.instapayLink);
                                  },
                            child: const Text('اشترِ الآن'),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('رفع إثبات التحويل', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
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
                  ),
                ),
              ),
              if (AppLayout.isWebDesktop(context)) const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}
