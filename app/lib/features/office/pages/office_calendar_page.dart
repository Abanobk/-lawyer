import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';

/// أجندة شهرية للجلسات (بند التقويم والمواعيد) — بدون اعتماد خارجي.
class OfficeCalendarPage extends StatefulWidget {
  const OfficeCalendarPage({super.key});

  @override
  State<OfficeCalendarPage> createState() => _OfficeCalendarPageState();
}

class _OfficeCalendarPageState extends State<OfficeCalendarPage> {
  final _api = SessionsApi();
  late Future<List<SessionDto>> _future = _api.list();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _reload() async {
    setState(() => _future = _api.list());
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  List<SessionDto> _sessionsInMonth(List<SessionDto> all) {
    return all.where((s) {
      final d = s.sessionDate.toLocal();
      return d.year == _month.year && d.month == _month.month;
    }).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
  }

  @override
  Widget build(BuildContext context) {
    final dfDay = DateFormat('EEEE d MMMM yyyy', 'ar');
    final dfShort = DateFormat('yyyy-MM-dd');
    final monthTitle = DateFormat('MMMM yyyy', 'ar').format(_month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_view_month_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'أجندة الجلسات',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(tooltip: 'تحديث', onPressed: _reload, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_right)),
                Expanded(
                  child: Text(
                    monthTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_left)),
                TextButton(
                  onPressed: () => setState(() => _month = DateTime(DateTime.now().year, DateTime.now().month)),
                  child: const Text('اليوم'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<SessionDto>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('تعذّر تحميل الجلسات: ${snap.error}'));
              }
              final list = _sessionsInMonth(snap.data ?? const []);
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'لا جلسات في $monthTitle',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }

              final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';

              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = list[i];
                  final local = s.sessionDate.toLocal();
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${local.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    title: Text(s.caseTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${dfDay.format(local)} · ${s.clientName}'
                      '${s.sessionNumber != null ? ' · جلسة ${s.sessionNumber}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: s.feeReminderDueAt != null
                        ? Tooltip(
                            message: 'متابعة مالية: ${dfShort.format(s.feeReminderDueAt!.toLocal())}',
                            child: Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.tertiary),
                          )
                        : null,
                    onTap: officeCode.isEmpty
                        ? null
                        : () => context.go('/o/$officeCode/cases/${s.caseId}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
