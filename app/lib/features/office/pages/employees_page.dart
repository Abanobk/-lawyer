import 'package:flutter/material.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Stub(title: 'إدارة الموظفين', icon: Icons.badge_outlined);
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
        subtitle: const Text('صلاحيات: مدير، محامي، استقبال — قريبًا'),
      ),
    );
  }
}
