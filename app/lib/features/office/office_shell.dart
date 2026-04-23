import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/config/tenant_build_config.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/theme/app_theme.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/core/util/role_labels.dart';
import 'package:lawyer_app/core/widgets/theme_appearance_menu.dart';
import 'package:lawyer_app/features/office/widgets/office_search_delegate.dart';
import 'package:lawyer_app/data/api/billing_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';
import 'package:lawyer_app/data/api/office_api.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';
import 'package:lawyer_app/features/office/office_welcome_context.dart';
import 'package:lawyer_app/features/office/widgets/subscription_trial_banner.dart';

class OfficeShell extends StatelessWidget {
  const OfficeShell({
    super.key,
    required this.officeCode,
    required this.child,
  });

  final String officeCode;
  final Widget child;

  String officeLinkForCurrentHost() {
    final origin = Uri.base.origin;
    return '$origin/o/$officeCode';
  }

  static const _items = <_OfficeNavItem>[
    _OfficeNavItem('dashboard', 'لوحة التحكم', Icons.dashboard_outlined),
    _OfficeNavItem('clients', 'الموكلين', Icons.people_outline),
    _OfficeNavItem('cases', 'القضايا', Icons.work_outline),
    _OfficeNavItem('sessions', 'الجلسات', Icons.calendar_month_outlined),
    _OfficeNavItem('calendar', 'الأجندة', Icons.calendar_view_month_outlined),
    _OfficeNavItem('accounts', 'الحسابات', Icons.account_balance_wallet_outlined),
    _OfficeNavItem('employees', 'الموظفين', Icons.badge_outlined),
    _OfficeNavItem('subscription', 'الاشتراك', Icons.subscriptions_outlined),
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
    final billingApi = BillingApi();

    return FutureBuilder<SubscriptionMeDto>(
      future: billingApi.subscriptionMe(),
      builder: (context, snap) {
        final banner = snap.hasData
            ? SubscriptionTrialBanner(
                sub: snap.data!,
                onSubscribe: () => context.go('/o/$officeCode/subscription'),
              )
            : const SizedBox.shrink();

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
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopOfficeHeader(
                          officeCode: officeCode,
                          officeLink: officeLinkForCurrentHost(),
                        ),
                        banner,
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

        final drawerW = math.min(320.0, MediaQuery.sizeOf(context).width * 0.88);
        Drawer buildDrawer() => Drawer(
              backgroundColor: AppColors.sidebar,
              surfaceTintColor: Colors.transparent,
              width: drawerW,
              child: _Sidebar(
                officeCode: officeCode,
                current: current,
                width: drawerW,
                inDrawer: true,
              ),
            );
        return Scaffold(
          // Mobile UX: always use endDrawer (right side) for Arabic.
          // Disable left-edge drag to avoid opening an empty/incorrect drawer on some Android builds.
          drawerEnableOpenDragGesture: false,
          endDrawerEnableOpenDragGesture: true,
          endDrawer: buildDrawer(),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'القائمة',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
            title: const Text('لوحة المكتب'),
            actions: [
              OfficeSearchLaunchButton(officeCode: officeCode),
              const ThemeAppearanceMenuButton(),
            ],
          ),
          body: ContentCanvas(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                banner,
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
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
    final meApi = MeApi();
    final origin = Uri.base.origin.trim();
    final officeLink = origin.isEmpty ? '/o/$officeCode' : '$origin/o/$officeCode';
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.balance, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مكتب المحاماة',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'من إيزي تك',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<OfficeDto?>(
                  future: () async {
                    try {
                      return await OfficeApi().myOffice();
                    } catch (_) {
                      return null;
                    }
                  }(),
                  builder: (context, snap) {
                    final name = snap.data?.name;
                    final line = name != null && name.isNotEmpty ? 'مكتب المستشار $name' : 'مكتب المستشار ($officeCode)';
                    return Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
                          ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        officeLink,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                        maxLines: 1,
                      ),
                    ),
                    IconButton(
                      tooltip: 'نسخ رابط المكتب',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: officeLink));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط المكتب')));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                    ),
                  ],
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
                        if (ps.connectionState != ConnectionState.done) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'جارٍ تحميل القائمة…',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _NavList(
                                  officeCode: officeCode,
                                  current: current,
                                  items: [OfficeShell._items.first],
                                ),
                              ),
                            ],
                          );
                        }

                        if (ps.hasError || !ps.hasData) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Text(
                                  'تعذر تحميل الصلاحيات — سيتم عرض قائمة مبسطة.',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                                ),
                              ),
                              Expanded(
                                child: _NavList(
                                  officeCode: officeCode,
                                  current: current,
                                  items: [OfficeShell._items.first],
                                ),
                              ),
                            ],
                          );
                        }

                        final keys = ps.data!.permissions.toSet();
                        var base = OfficeShell._items.where((i) => _allowNav(i.segment, keys)).toList();
                        if (base.isEmpty) {
                          base = [OfficeShell._items.first];
                        }
                        return FutureBuilder<MeDto>(
                          future: meApi.me(),
                          builder: (context, ms) {
                            final role = ms.data?.role;
                            final items = base.where((i) => i.segment != 'subscription' || role == 'office_owner').toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (role != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                                    child: Text(
                                      'دورك: ${roleLabelAr(role)}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                Expanded(
                                  child: _NavList(officeCode: officeCode, current: current, items: items),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.maybePop(context);
                  await AuthTokenStorage().clear();
                  if (!context.mounted) return;
                  context.go(TenantBuildConfig.isTenantApk ? '/login' : '/');
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
    case 'calendar':
      required = 'cases.read';
      break;
    case 'accounts':
      required = 'accounts.read';
      break;
    case 'employees':
      required = 'employees.read';
      break;
    case 'subscription':
      required = 'settings.view';
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
  const _DesktopOfficeHeader({
    required this.officeCode,
    required this.officeLink,
  });

  final String officeCode;
  final String officeLink;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 20, top: 6, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: officeLink));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط المكتب')));
                  }
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('نسخ رابط المكتب'),
              ),
              const ThemeAppearanceMenuButton(),
              OfficeSearchLaunchButton(officeCode: officeCode),
              const Spacer(),
              FutureBuilder<(MeDto, OfficeDto)>(
                future: loadOfficeWelcomeContext(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                          foregroundColor: AppColors.primaryBlue,
                          child: const Text('…'),
                        ),
                      ],
                    );
                  }
                  final me = snap.data!.$1;
                  final off = snap.data!.$2;
                  final who = officeUserDisplayName(me);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'مرحبًا بك أستاذ $who',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'في مكتب المستشار ${off.name}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'دورك: ${roleLabelAr(me.role)}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        foregroundColor: AppColors.primaryBlue,
                        child: Text(
                          officeUserInitial(me),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
