import 'package:flutter/material.dart';

class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Stub(title: 'الجلسات', icon: Icons.calendar_month_outlined);
  }
}

class _Stub extends StatelessWidget {
  const _Stub({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: const Text('تقويم الجلسات والتنبيهات — قريبًا'),
      ),
    );
  }
}
