import 'package:flutter/material.dart';

/// يطابق تسميات [PERMISSIONS] في الباكند (للعرض للمستأجر).
const Map<String, String> kPermissionLabelsAr = {
  'dashboard.view': 'لوحة التحكم',
  'clients.read': 'الموكلين (عرض)',
  'clients.create': 'إضافة موكل',
  'cases.read': 'القضايا (عرض)',
  'cases.create': 'إضافة قضية',
  'cases.upload': 'رفع مرفقات القضية',
  'sessions.update': 'الجلسات (تعديل المواعيد)',
  'accounts.read': 'الحسابات',
  'employees.read': 'الموظفين (عرض)',
  'employees.manage': 'إدارة الموظفين والصلاحيات',
  'custody.me': 'عهدة الموظف',
  'custody.spend.create': 'مصروف من العهدة',
  'custody.admin.view': 'إدارة العهد (عرض)',
  'custody.admin.advance': 'إضافة عهدة/سلفة',
  'custody.admin.approve': 'اعتماد مصروفات العهدة',
  'settings.view': 'الإعدادات',
};

String labelForPermKey(String key) => kPermissionLabelsAr[key] ?? key;

/// سطر قابل للضغط: «عدد وحدات التحكم: n» مع حوار يوضح الوحدات.
Widget controlUnitsCountLine(BuildContext context, List<String>? keys) {
  final theme = Theme.of(context);
  if (keys == null || keys.isEmpty) {
    return Text(
      'وحدات التحكم: غير محددة في الباقة — راجع الأدمن',
      style: theme.textTheme.bodyMedium,
    );
  }
  final n = keys.length;
  final sorted = List<String>.from(keys)..sort();
  return InkWell(
    onTap: () {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('وحدات التحكم ($n)'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in sorted) Text('• ${labelForPermKey(k)}', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      );
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        'عدد وحدات التحكم: $n',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        ),
      ),
    ),
  );
}
