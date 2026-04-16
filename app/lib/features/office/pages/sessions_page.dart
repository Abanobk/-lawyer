import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _api = SessionsApi();
  late Future<List<SessionDto>> _future = _api.list();

  void _reload() => setState(() => _future = _api.list());

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'الجلسات',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: FutureBuilder<List<SessionDto>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('تعذر تحميل الجلسات: ${snap.error}'));
                }
                final items = snap.data ?? const <SessionDto>[];
                if (items.isEmpty) {
                  return const Center(child: Text('لا يوجد جلسات بعد'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('الموكل')),
                      DataColumn(label: Text('القضية')),
                      DataColumn(label: Text('رقم/سنة')),
                    ],
                    rows: items
                        .map(
                          (s) => DataRow(
                            cells: [
                              DataCell(Text(df.format(s.sessionDate.toLocal()))),
                              DataCell(Text(s.clientName)),
                              DataCell(Text(s.caseTitle)),
                              DataCell(Text(_numYear(s.sessionNumber, s.sessionYear))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _numYear(String? n, int? y) {
    if ((n == null || n.isEmpty) && y == null) return '—';
    if (n == null || n.isEmpty) return '—/$y';
    if (y == null) return '$n/—';
    return '$n/$y';
  }
}
