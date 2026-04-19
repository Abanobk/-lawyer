import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lawyer_app/data/api/mobile_build_api.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// بطاقة تحميل تطبيق أندرويد (white-label) حسب آخر إصدار مسجّل في الخادم.
///
/// يُحدَّث العرض تلقائياً عند عودة المستخدم للتطبيق/التبويب، وكل بضع دقائق
/// طالما البطاقة ظاهرة، حتى يظهر إصدار جديد بمجرد تسجيله من الـ CI.
class OfficeMobileDownloadCard extends StatefulWidget {
  const OfficeMobileDownloadCard({super.key});

  @override
  State<OfficeMobileDownloadCard> createState() => _OfficeMobileDownloadCardState();
}

class _OfficeMobileDownloadCardState extends State<OfficeMobileDownloadCard> with WidgetsBindingObserver {
  late Future<OfficeMobileDownloadDto?> _future = MobileBuildApi().latestForMyOffice();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(const Duration(minutes: 3), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _silentRefresh();
    }
  }

  void _reload() => setState(() => _future = MobileBuildApi().latestForMyOffice());

  /// تحديث خلفي بدون إعادة شاشة التحميل بالكامل.
  Future<void> _silentRefresh() async {
    if (!mounted) return;
    try {
      final next = await MobileBuildApi().latestForMyOffice();
      if (!mounted) return;
      setState(() => _future = Future.value(next));
    } catch (_) {
      /* تجاهل أخطاء الشبكة في الخلفية؛ المستخدم يضغط «تحديث» إن لزم */
    }
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رابط التحميل غير صالح')));
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحميل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<OfficeMobileDownloadDto?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Row(
                children: [
                  SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('جاري التحقق من إصدار التطبيق…'),
                ],
              );
            }
            if (snap.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('تعذر تحميل معلومات التطبيق: ${snap.error}', style: TextStyle(color: scheme.error)),
                  TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                ],
              );
            }
            final data = snap.data;
            if (data == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.android_outlined, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text('تطبيق أندرويد للمكتب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا يوجد ملف APK مسجّل بعد. بعد أول بناء من الأتمتة (CI) سيظهر هنا رابط التحميل والإصدار. '
                    'يتم التحقق تلقائياً كل بضع دقائق وعند العودة للصفحة.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                  TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('تحديث')),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.android_outlined, color: scheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تطبيق أندرويد للمكتب',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'إصدار ${data.versionName} (رمز ${data.versionCode}) — بني في ${df.format(data.builtAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (data.releaseNotes != null && data.releaseNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(data.releaseNotes!.trim(), style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 10),
                Text(
                  'كلما يُسجَّل إصدار أحدث على الخادم يظهر هنا تلقائياً (تحديث دوري وعند العودة للتطبيق). '
                  'للتثبيت على الموبايل: افتح هذه الصفحة من متصفح الجهاز واضغط «تحميل APK»، ثم اسمح بتثبيت التطبيقات من مصادر غير معروفة إذا طلب أندرويد ذلك.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openDownload(data.downloadUrl),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('تحميل APK'),
                ),
                if (data.sha256Hex != null && data.sha256Hex!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    'SHA-256: ${data.sha256Hex}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
