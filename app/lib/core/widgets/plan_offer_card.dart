import 'package:flutter/material.dart';

/// بطاقة عرض باقة (صورة علوية + تفاصيل) — مستخدمة في اشتراك المستأجر ومعاينة السوبر أدمن.
class PlanOfferCard extends StatelessWidget {
  const PlanOfferCard({
    super.key,
    required this.title,
    required this.optionName,
    required this.priceText,
    required this.durationText,
    this.maxUsersText,
    this.permCountText,
    this.packageKeyText,
    this.footerHint,
    required this.image,
    this.selected = false,
    this.footer,
  });

  final String title;
  final String optionName;
  final String priceText;
  final String durationText;
  final String? maxUsersText;
  final String? permCountText;
  final String? packageKeyText;
  final String? footerHint;
  final Widget image;
  final bool selected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 8 : 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: selected ? BorderSide(color: cs.primary, width: 2.5) : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: image,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text('الخيار: $optionName', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(priceText, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(durationText),
                if (maxUsersText != null) Text(maxUsersText!),
                if (permCountText != null) Text(permCountText!),
                if (packageKeyText != null && packageKeyText!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'مفتاح التجميع: $packageKeyText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (footerHint != null && footerHint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(footerHint!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
