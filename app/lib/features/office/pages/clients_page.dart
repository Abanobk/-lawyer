import 'package:flutter/material.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlaceholderModule(
      title: 'إدارة الموكلين',
      icon: Icons.people_outline,
      primaryAction: 'إضافة موكل جديد',
    );
  }
}

class _PlaceholderModule extends StatelessWidget {
  const _PlaceholderModule({
    required this.title,
    required this.icon,
    required this.primaryAction,
  });

  final String title;
  final IconData icon;
  final String primaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: Text(primaryAction),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'جدول البيانات والبحث — يُربط بالـ API لاحقًا',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
