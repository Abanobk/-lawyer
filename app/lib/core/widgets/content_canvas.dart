import 'package:flutter/material.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';

/// يلف محتوى الصفحات على الويب العريض بحد أقصى للعرض وتوسيط، لتفادي الشكل «الممتد».
class ContentCanvas extends StatelessWidget {
  const ContentCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = AppLayout.contentMaxWidth(context);
    final padding = AppLayout.pagePadding(context);

    if (!AppLayout.useCenteredContentCanvas(context)) {
      return Padding(padding: padding, child: child);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
