import 'package:flutter/material.dart';

/// بطاقة باقة: صورة دعائية كاملة (بدون قص) + تفاصيل مشتركة + أزرار/إجراءات (مثل خيارات اشتراك متعددة).
class PlanOfferCard extends StatelessWidget {
  const PlanOfferCard({
    super.key,
    required this.title,
    required this.image,
    this.packageKeyText,
    this.sharedDetailLines = const [],
    this.footerHint,
    this.actions = const [],
    this.selected = false,
    this.imageMaxHeight = 320,
  });

  final String title;
  final Widget image;
  final String? packageKeyText;
  final List<String> sharedDetailLines;
  final String? footerHint;
  final List<Widget> actions;
  final bool selected;
  final double imageMaxHeight;

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
          SizedBox(
            height: imageMaxHeight,
            width: double.infinity,
            child: ColoredBox(
              color: const Color(0xFFF3F5F9),
              child: image,
            ),
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
                if (sharedDetailLines.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final line in sharedDetailLines) Text(line),
                ],
                if (packageKeyText != null && packageKeyText!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'مفتاح التجميع: $packageKeyText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (footerHint != null && footerHint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(footerHint!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
