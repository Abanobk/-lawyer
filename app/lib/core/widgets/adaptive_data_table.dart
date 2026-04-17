import 'package:flutter/material.dart';

/// جدول على الشاشات العريضة، وبطاقات على الضيقة (نقطة ٣).
class AdaptiveDataTable extends StatelessWidget {
  const AdaptiveDataTable({
    super.key,
    required this.headers,
    required this.rows,
    this.breakpointWidth = 720,
    this.minTableWidth = 520,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final double breakpointWidth;
  final double? minTableWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < breakpointWidth;
        if (!narrow) {
          final table = DataTable(
            columns: [for (final h in headers) DataColumn(label: Text(h))],
            rows: [
              for (final r in rows)
                DataRow(
                  cells: [for (final cell in r) DataCell(Text(cell))],
                ),
            ],
          );
          final minW = minTableWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: minW != null
                ? ConstrainedBox(
                    constraints: BoxConstraints(minWidth: minW),
                    child: table,
                  )
                : table,
          );
        }

        if (rows.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            for (final r in rows)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < r.length && i < headers.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i < r.length - 1 ? 8 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 112,
                                child: Text(
                                  headers[i],
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Text(r[i], style: Theme.of(context).textTheme.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
