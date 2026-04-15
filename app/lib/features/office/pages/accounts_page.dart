import 'package:flutter/material.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Stub(title: 'الإدارة المالية', icon: Icons.account_balance_wallet_outlined);
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
        subtitle: const Text('إيرادات ومصروفات لكل قضية — قريبًا'),
      ),
    );
  }
}
