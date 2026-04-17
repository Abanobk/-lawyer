import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/reports_api.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';
import 'package:lawyer_app/features/office/office_welcome_context.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardData {
  _DashboardData({
    required this.clients,
    required this.cases,
    required this.sessions,
    required this.custodyPendingSpends,
  });

  final List<ClientDto> clients;
  final List<CaseDto> cases;
  final List<SessionDto> sessions;
  final double custodyPendingSpends;
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<_DashboardData> _load() async {
    final clientsF = ClientsApi().list();
    final casesF = CasesApi().list();
    final sessionsF = SessionsApi().list();
    var custodyPending = 0.0;
    try {
      final rep = await ReportsApi().custody();
      for (final r in rep) {
        custodyPending += r.pendingSpendsSum;
      }
    } catch (_) {}

    final results = await Future.wait([clientsF, casesF, sessionsF]);
    return _DashboardData(
      clients: results[0] as List<ClientDto>,
      cases: results[1] as List<CaseDto>,
      sessions: results[2] as List<SessionDto>,
      custodyPendingSpends: custodyPending,
    );
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  String _kindLabel(String v) {
    switch (v) {
      case 'misdemeanor':
        return 'جنح';
      case 'felony':
        return 'جنايات';
      case 'civil':
        return 'مدني';
      case 'family':
        return 'أسرة';
      default:
        return 'أخرى';
    }
  }

  String _caseRef(CaseDto c) {
    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) {
      if (c.caseYear != null) return '${c.caseNumber}/${c.caseYear}';
      return c.caseNumber!;
    }
    return '${c.id}';
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppLayout.isWebDesktop(context);
    final officeCode = GoRouterState.of(context).pathParameters['officeCode'] ?? '';
    final df = DateFormat('yyyy-MM-dd');

    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تعذّر تحميل لوحة التحكم: ${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
              ],
            ),
          );
        }
        final data = snap.data!;
        final now = DateTime.now();
        final todayStart = _startOfDay(now);
        final upcomingSessions = data.sessions.where((s) {
          final d = _startOfDay(s.sessionDate.toLocal());
          return !d.isBefore(todayStart);
        }).length;
        final openCases = data.cases.where((c) => c.isActive).length;

        final todaySessions = data.sessions.where((s) => _startOfDay(s.sessionDate.toLocal()) == todayStart).toList()
          ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

        final weekEnd = todayStart.add(const Duration(days: 8));
        final feeReminders = data.sessions.where((s) {
          final due = s.feeReminderDueAt;
          if (due == null) return false;
          final ld = _startOfDay(due.toLocal());
          return !ld.isBefore(todayStart) && ld.isBefore(weekEnd);
        }).toList()
          ..sort((a, b) => (a.feeReminderDueAt ?? a.sessionDate).compareTo(b.feeReminderDueAt ?? b.sessionDate));

        final activeCases = data.cases.where((c) => c.isActive).toList();
        activeCases.sort((a, b) {
          final ah = a.firstHearingAt;
          final bh = b.firstHearingAt;
          if (ah == null && bh == null) return b.createdAt.compareTo(a.createdAt);
          if (ah == null) return 1;
          if (bh == null) return -1;
          return ah.compareTo(bh);
        });
        final previewCases = activeCases.take(12).toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroBanner(
                upcomingSessions: upcomingSessions,
                openCases: openCases,
                custodyPending: data.custodyPendingSpends,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  final cross = wide ? 4 : 2;
                  final spacing = wide ? 20.0 : 12.0;
                  final w = (c.maxWidth - spacing * (cross - 1)) / cross;
                  final money = NumberFormat('#,##0.00', 'ar');
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      _KpiCard(
                        width: w,
                        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                        icon: Icons.schedule,
                        iconColor: Theme.of(context).colorScheme.error,
                        value: '$upcomingSessions',
                        label: 'جلسات قادمة (من اليوم)',
                        onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/calendar'),
                      ),
                      _KpiCard(
                        width: w,
                        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                        icon: Icons.folder_open,
                        iconColor: Theme.of(context).colorScheme.onTertiaryContainer,
                        value: '$openCases',
                        label: 'قضايا مفتوحة',
                        onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases'),
                      ),
                      _KpiCard(
                        width: w,
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
                        icon: Icons.work_outline,
                        iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        value: '${data.cases.length}',
                        label: 'إجمالي القضايا',
                        onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases'),
                      ),
                      _KpiCard(
                        width: w,
                        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.45),
                        icon: Icons.people_outline,
                        iconColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        value: '${data.clients.length}',
                        label: 'الموكلين',
                        onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/clients'),
                      ),
                      if (data.custodyPendingSpends > 0.009)
                        _KpiCard(
                          width: w,
                          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: Theme.of(context).colorScheme.error,
                          value: money.format(data.custodyPendingSpends),
                          label: 'عهدة معلّقة (إجمالي)',
                          onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/accounts?tab=custody'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('آخر تحديث', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 8),
                  IconButton(tooltip: 'تحديث اللوحة', onPressed: _reload, icon: const Icon(Icons.refresh, size: 20)),
                ],
              ),
              const SizedBox(height: 8),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CasesPreviewCard(
                        cases: previewCases,
                        officeCode: officeCode,
                        kindLabel: _kindLabel,
                        caseRef: _caseRef,
                        df: df,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: _SessionAlertsCard(
                        todaySessions: todaySessions,
                        feeReminders: feeReminders,
                        custodyPending: data.custodyPendingSpends,
                        officeCode: officeCode,
                        df: df,
                      ),
                    ),
                  ],
                )
              else ...[
                _CasesPreviewCard(
                  cases: previewCases,
                  officeCode: officeCode,
                  kindLabel: _kindLabel,
                  caseRef: _caseRef,
                  df: df,
                ),
                const SizedBox(height: 16),
                _SessionAlertsCard(
                  todaySessions: todaySessions,
                  feeReminders: feeReminders,
                  custodyPending: data.custodyPendingSpends,
                  officeCode: officeCode,
                  df: df,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.upcomingSessions,
    required this.openCases,
    required this.custodyPending,
  });

  final int upcomingSessions;
  final int openCases;
  final double custodyPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2744), Color(0xFF1E3A8A)],
        ),
      ),
      child: FutureBuilder<(MeDto, OfficeDto)>(
        future: loadOfficeWelcomeContext(),
        builder: (context, snap) {
          final who = snap.hasData ? officeUserDisplayName(snap.data!.$1) : '…';
          final officeName = snap.hasData ? snap.data!.$2.name : '…';
          final sub = custodyPending > 0.009
              ? 'لديك $upcomingSessions جلسة قادمة، و$openCases قضية مفتوحة، ومصروفات عهدة بانتظار الاعتماد.'
              : 'لديك $upcomingSessions جلسة قادمة من اليوم، و$openCases قضية مفتوحة — اختصر المتابعة من البطاقات أدناه.';
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحبًا بك أستاذ $who',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'في مكتب المستشار $officeName',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                            height: 1.4,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.balance, size: 72, color: Colors.white.withValues(alpha: 0.2)),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.onTap,
  });

  final double width;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return SizedBox(width: width, child: child);
    return SizedBox(
      width: width,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: child),
    );
  }
}

class _CasesPreviewCard extends StatelessWidget {
  const _CasesPreviewCard({
    required this.cases,
    required this.officeCode,
    required this.kindLabel,
    required this.caseRef,
    required this.df,
  });

  final List<CaseDto> cases;
  final String officeCode;
  final String Function(String) kindLabel;
  final String Function(CaseDto) caseRef;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'قضايا نشطة (لمحة)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases'),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const Divider(),
            if (cases.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'لا توجد قضايا مفتوحة حاليًا.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 48,
                  columns: const [
                    DataColumn(label: Text('رقم/مرجع')),
                    DataColumn(label: Text('الموكل')),
                    DataColumn(label: Text('العنوان')),
                    DataColumn(label: Text('المحكمة')),
                    DataColumn(label: Text('النوع')),
                    DataColumn(label: Text('أول جلسة')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('إجراء')),
                  ],
                  rows: cases
                      .map(
                        (c) => DataRow(
                          onSelectChanged: (_) {
                            if (officeCode.isEmpty) return;
                            context.go('/o/$officeCode/cases/${c.id}');
                          },
                          cells: [
                            DataCell(Text(caseRef(c))),
                            DataCell(Text(c.clientName)),
                            DataCell(Text(c.title, maxLines: 2)),
                            DataCell(Text(c.court ?? '—')),
                            DataCell(Text(kindLabel(c.kind))),
                            DataCell(Text(c.firstHearingAt == null ? '—' : df.format(c.firstHearingAt!.toLocal()))),
                            DataCell(
                              Chip(
                                label: Text(c.isActive ? 'مفتوحة' : 'مغلقة'),
                                backgroundColor: c.isActive
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases/${c.id}'),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionAlertsCard extends StatelessWidget {
  const _SessionAlertsCard({
    required this.todaySessions,
    required this.feeReminders,
    required this.custodyPending,
    required this.officeCode,
    required this.df,
  });

  final List<SessionDto> todaySessions;
  final List<SessionDto> feeReminders;
  final double custodyPending;
  final String officeCode;
  final DateFormat df;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00', 'ar');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تنبيهات ومواعيد',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/sessions'),
                  child: const Text('الجلسات'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (custodyPending > 0.009) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                title: const Text('عهدة: مصروفات بانتظار الاعتماد'),
                subtitle: Text('إجمالي معلّق: ${money.format(custodyPending)} ج.م'),
                trailing: TextButton(
                  onPressed: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/accounts?tab=custody'),
                  child: const Text('مراجعة'),
                ),
              ),
              const Divider(),
            ],
            Text(
              'جلسات اليوم',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (todaySessions.isEmpty)
              Text(
                'لا جلسات مسجّلة اليوم.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...todaySessions.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(s.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.clientName),
                  onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases/${s.caseId}'),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'متابعات مالية قريبة (٧ أيام)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (feeReminders.isEmpty)
              Text(
                'لا توجد مواعيد متابعة أتعاب في الأسبوع الحالي.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...feeReminders.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.payments_outlined, color: Theme.of(context).colorScheme.tertiary),
                  title: Text(s.caseTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${s.clientName} · استحقاق: ${s.feeReminderDueAt != null ? df.format(s.feeReminderDueAt!.toLocal()) : '—'}'
                    '${s.feeReminderAmount != null ? ' · ${money.format(s.feeReminderAmount!)}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: officeCode.isEmpty ? null : () => context.go('/o/$officeCode/cases/${s.caseId}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
