import 'package:flutter/material.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = AppLayout.isWebDesktop(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBanner(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final cross = wide ? 4 : 2;
              final spacing = wide ? 20.0 : 12.0;
              final w = (c.maxWidth - spacing * (cross - 1)) / cross;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _KpiCard(
                    width: w,
                    color: Colors.red.shade50,
                    icon: Icons.schedule,
                    iconColor: Colors.red.shade700,
                    value: '2',
                    label: 'جلسات قادمة',
                  ),
                  _KpiCard(
                    width: w,
                    color: Colors.amber.shade50,
                    icon: Icons.folder_open,
                    iconColor: Colors.amber.shade800,
                    value: '1',
                    label: 'قضايا مفتوحة',
                  ),
                  _KpiCard(
                    width: w,
                    color: Colors.green.shade50,
                    icon: Icons.work_outline,
                    iconColor: Colors.green.shade700,
                    value: '1',
                    label: 'إجمالي القضايا',
                  ),
                  _KpiCard(
                    width: w,
                    color: Colors.blue.shade50,
                    icon: Icons.people_outline,
                    iconColor: Colors.blue.shade700,
                    value: '1',
                    label: 'الموكلين',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _CasesPreviewCard()),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: _SessionAlertsCard()),
              ],
            )
          else ...[
            _CasesPreviewCard(),
            const SizedBox(height: 16),
            _SessionAlertsCard(),
          ],
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحبًا، أ/ المدير العام',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لديك جلسات قادمة تحتاج لمتابعتك — سيتم ربط الأرقام بالـ API.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.balance, size: 72, color: Colors.white.withValues(alpha: 0.2)),
        ],
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
  });

  final double width;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
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
      ),
    );
  }
}

class _CasesPreviewCard extends StatelessWidget {
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
                  'المهام والقضايا الحالية',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const Divider(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                columns: const [
                  DataColumn(label: Text('رقم القضية')),
                  DataColumn(label: Text('الموكل')),
                  DataColumn(label: Text('المحكمة')),
                  DataColumn(label: Text('الحالة')),
                  DataColumn(label: Text('إجراء')),
                ],
                rows: [
                  DataRow(
                    cells: [
                      const DataCell(Text('12355412')),
                      const DataCell(Text('محمد كمال إبراهيم')),
                      const DataCell(Text('التجمع الأول')),
                      DataCell(
                        Chip(
                          label: const Text('مفتوحة'),
                          backgroundColor: Colors.green.shade50,
                          labelStyle: TextStyle(color: Colors.green.shade800, fontSize: 12),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionAlertsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Text(
                  'تنبيهات الجلسات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لا توجد جلسات لك اليوم (بيانات تجريبية)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
