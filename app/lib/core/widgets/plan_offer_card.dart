import 'package:flutter/material.dart';

/// بطاقة باقة: صورة دعائية كاملة (بدون قص) + تفاصيل مشتركة + أزرار/إجراءات (مثل خيارات اشتراك متعددة).
class PlanOfferCard extends StatelessWidget {
  const PlanOfferCard({
    super.key,
    required this.title,
    required this.image,
    this.packageKeyText,
    this.sharedDetailLines = const [],
    this.sharedDetailWidgets,
    this.footerHint,
    this.actions = const [],
    this.selected = false,
    this.imageMaxHeight,
  });

  final String title;
  final Widget image;
  final String? packageKeyText;
  final List<String> sharedDetailLines;
  /// إن وُجدت تُعرض بدل [sharedDetailLines].
  final List<Widget>? sharedDetailWidgets;
  final String? footerHint;
  final List<Widget> actions;
  final bool selected;
  /// إن كان `null` يُسمح لمنطقة الصورة بتحديد الارتفاع من المحتوى (مثل [PromoImageMemory]).
  final double? imageMaxHeight;

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
          imageMaxHeight != null
              ? SizedBox(
                  height: imageMaxHeight,
                  width: double.infinity,
                  child: ColoredBox(
                    color: const Color(0xFFEEF2F7),
                    child: image,
                  ),
                )
              : ColoredBox(
                  color: const Color(0xFFEEF2F7),
                  child: image,
                ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sharedDetailWidgets != null && sharedDetailWidgets!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...sharedDetailWidgets!,
                ] else if (sharedDetailLines.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final line in sharedDetailLines) Text(line, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (packageKeyText != null && packageKeyText!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'مفتاح التجميع: $packageKeyText',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (footerHint != null && footerHint!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(footerHint!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
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
