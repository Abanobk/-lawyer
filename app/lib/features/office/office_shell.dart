import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';

class OfficeShell extends StatelessWidget {
  const OfficeShell({
    super.key,
    required this.officeCode,
    required this.child,
  });

  final String officeCode;
  final Widget child;

  static const _items = <_OfficeNavItem>[
    _OfficeNavItem('dashboard', 'لوحة التحكم', Icons.dashboard_outlined),
    _OfficeNavItem('clients', 'الموكلين', Icons.people_outline),
    _OfficeNavItem('cases', 'القضايا', Icons.work_outline),
    _OfficeNavItem('sessions', 'الجلسات', Icons.calendar_month_outlined),
    _OfficeNavItem('accounts', 'الحسابات', Icons.account_balance_wallet_outlined),
    _OfficeNavItem('custody', 'العُهد', Icons.payments_outlined),
    _OfficeNavItem('employees', 'الموظفين', Icons.badge_outlined),
    _OfficeNavItem('settings', 'الإعدادات', Icons.settings_outlined),
  ];

  String _currentSegment(BuildContext context) {
    final segs = GoRouterState.of(context).uri.pathSegments;
    if (segs.length >= 3) return segs[2];
    return 'dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AppLayout.isWebDesktop(context);
    final current = _currentSegment(context);

    if (desktop) {
      return Scaffold(
        body: Row(
          textDirection: TextDirection.rtl,
          children: [
            _Sidebar(
              officeCode: officeCode,
              current: current,
              width: 280,
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.surfaceMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DesktopOfficeHeader(),
                    Expanded(
                      child: ContentCanvas(child: child),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: _Sidebar(
          officeCode: officeCode,
          current: current,
          width: null,
          inDrawer: true,
        ),
      ),
      appBar: AppBar(
        title: const Text('لوحة المكتب'),
      ),
      body: ContentCanvas(child: child),
    );
  }
}

class _OfficeNavItem {
  const _OfficeNavItem(this.segment, this.label, this.icon);
  final String segment;
  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.officeCode,
    required this.current,
    required this.width,
    this.inDrawer = false,
  });

  final String officeCode;
  final String current;
  final double? width;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final tokens = AuthTokenStorage();
    final permsApi = PermissionsApi();
    final nav = Material(
      color: AppColors.sidebar,
      child: SafeArea(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.balance, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'مكتب المحاماة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  officeCode,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<String?>(
                  future: tokens.getAccessToken(),
                  builder: (context, snap) {
                    final hasAuth = (snap.data ?? '').isNotEmpty;
                    if (!hasAuth) {
                      final items = [OfficeShell._items.first];
                      return _NavList(officeCode: officeCode, current: current, items: items);
                    }
                    return FutureBuilder<UserPermissionsDto>(
                      future: permsApi.myPermissions(),
                      builder: (context, ps) {
                        final keys = ps.data?.permissions.toSet() ?? const <String>{};
                        final items = OfficeShell._items.where((i) => _allowNav(i.segment, keys)).toList();
                        return _NavList(officeCode: officeCode, current: current, items: items);
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.maybePop(context);
                  context.go('/');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    return nav;
  }
}

bool _allowNav(String segment, Set<String> keys) {
  String? required;
  switch (segment) {
    case 'dashboard':
      required = 'dashboard.view';
      break;
    case 'clients':
      required = 'clients.read';
      break;
    case 'cases':
      required = 'cases.read';
      break;
    case 'sessions':
      required = 'cases.read';
      break;
    case 'accounts':
      required = 'accounts.read';
      break;
    case 'custody':
      return keys.contains('custody.me') ||
          keys.contains('custody.admin.view') ||
          keys.contains('custody.admin.advance') ||
          keys.contains('custody.admin.approve');
    case 'employees':
      required = 'employees.read';
      break;
    case 'settings':
      required = 'settings.view';
      break;
  }
  if (required == null) return true;
  return keys.contains(required);
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.officeCode,
    required this.current,
    required this.items,
  });

  final String officeCode;
  final String current;
  final List<_OfficeNavItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final selected = item.segment == current;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected ? AppColors.sidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go('/o/$officeCode/${item.segment}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(item.icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.label, style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopOfficeHeader extends StatelessWidget {
  const _DesktopOfficeHeader();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 20),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  'مرحبًا، المدير العام',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                  foregroundColor: AppColors.primaryBlue,
                  child: const Text('م'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
