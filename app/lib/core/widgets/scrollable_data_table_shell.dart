import 'package:flutter/material.dart';

/// يلف [DataTable] بتمرير عمودي ثم أفقي لتفادي القص على الهاتف والويب الضيق.
class ScrollableDataTableShell extends StatelessWidget {
  const ScrollableDataTableShell({
    super.key,
    required this.table,
    this.padding = const EdgeInsets.all(12),
  });

  final DataTable table;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    );
  }
}
