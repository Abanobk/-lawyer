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

class OfficeShell extends StatefulWidget {
  const OfficeShell({super.key, required this.officeCode, required this.child});

  final String officeCode;
  final Widget child;

  static const _items = <_OfficeNavItem>[
    _OfficeNavItem('dashboard', 'لوحة التحكم', Icons.dashboard_outlined),
    _OfficeNavItem('clients', 'الموكلين', Icons.people_outline),
    _OfficeNavItem('cases', 'القضايا', Icons.work_outline),
    _OfficeNavItem('sessions', 'الجلسات', Icons.calendar_month_outlined),
    _OfficeNavItem('calendar', 'الأجندة', Icons.calendar_view_month_outlined),
    _OfficeNavItem(
      'accounts',
      'الحسابات',
      Icons.account_balance_wallet_outlined,
    ),
    _OfficeNavItem('employees', 'الموظفين', Icons.badge_outlined),
    _OfficeNavItem('subscription', 'الاشتراك', Icons.subscriptions_outlined),
    _OfficeNavItem('settings', 'الإعدادات', Icons.settings_outlined),
  ];

  @override
  State<OfficeShell> createState() => _OfficeShellState();
}

class _OfficeShellState extends State<OfficeShell> {
  bool _drawerOpen = false;
  final GlobalKey<ScaffoldState> _mobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  late final Future<SubscriptionMeDto> _subscriptionFuture = BillingApi()
      .subscriptionMe();

  String _officeLinkForCurrentHost() {
    final origin = Uri.base.origin;
    return '$origin/o/${widget.officeCode}';
  }

  String _currentSegment(BuildContext context) {
    final segs = GoRouterState.of(context).uri.pathSegments;
    if (segs.length >= 3) return segs[2];
    return 'dashboard';
  }

  @override
  Widget build(BuildContext context) {
    final desktop = AppLayout.isWebDesktop(context);
    final current = _currentSegment(context);

    return FutureBuilder<SubscriptionMeDto>(
      future: _subscriptionFuture,
      builder: (context, snap) {
        final banner = snap.hasData
            ? SubscriptionTrialBanner(
                sub: snap.data!,
                onSubscribe: () =>
                    context.go('/o/${widget.officeCode}/subscription'),
              )
            : const SizedBox.shrink();

        if (desktop) {
          return Scaffold(
            body: Row(
              textDirection: TextDirection.rtl,
              children: [
                _Sidebar(
                  officeCode: widget.officeCode,
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
                          officeCode: widget.officeCode,
                          officeLink: _officeLinkForCurrentHost(),
                        ),
                        banner,
                        Expanded(child: ContentCanvas(child: widget.child)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final drawerW = math.min(
          320.0,
          MediaQuery.sizeOf(context).width * 0.88,
        );

        void closeMobileDrawer() {
          _mobileScaffoldKey.currentState?.closeDrawer();
        }

        // RTL: الـ drawer (من جهة البداية) يفتح من اليمين — نفس سلوك الويب.
        // الـ Stack المخصص كان يسبب طبقات رسم/قيود غريبة على بعض أجهزة Android.
        return PopScope(
          canPop: !_drawerOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_drawerOpen) closeMobileDrawer();
          },
          child: Scaffold(
            key: _mobileScaffoldKey,
            onDrawerChanged: (open) {
              if (_drawerOpen != open) setState(() => _drawerOpen = open);
            },
            drawer: Drawer(
              width: drawerW,
              backgroundColor: AppColors.sidebar,
              surfaceTintColor: Colors.transparent,
              child: Material(
                color: AppColors.sidebar,
                type: MaterialType.canvas,
                surfaceTintColor: Colors.transparent,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    scaffoldBackgroundColor: AppColors.sidebar,
                    canvasColor: AppColors.sidebar,
                    splashColor: Colors.white24,
                    highlightColor: Colors.white24,
                    iconTheme: const IconThemeData(color: Colors.white),
                    listTileTheme: const ListTileThemeData(
                      iconColor: Colors.white,
                      textColor: Colors.white,
                    ),
                    textTheme: Theme.of(context).textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                  ),
                  child: _Sidebar(
                    officeCode: widget.officeCode,
                    current: current,
                    width: drawerW,
                    inDrawer: true,
                    onCloseDrawer: closeMobileDrawer,
                  ),
                ),
              ),
            ),
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: IconButton(
                tooltip: 'القائمة',
                icon: const Icon(Icons.menu),
                onPressed: () =>
                    _mobileScaffoldKey.currentState?.openDrawer(),
              ),
              title: const Text('لوحة المكتب'),
              actions: [
                OfficeSearchLaunchButton(officeCode: widget.officeCode),
                const ThemeAppearanceMenuButton(),
              ],
            ),
            body: ContentCanvas(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  banner,
                  Expanded(child: widget.child),
                ],
              ),
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
    this.onCloseDrawer,
  });

  final String officeCode;
  final String current;
  final double? width;
  final bool inDrawer;
  final VoidCallback? onCloseDrawer;

  @override
  Widget build(BuildContext context) {
    final tokens = AuthTokenStorage();
    final permsApi = PermissionsApi();
    final meApi = MeApi();
    final origin = Uri.base.origin.trim();
    final officeLink = origin.isEmpty
        ? '/o/$officeCode'
        : '$origin/o/$officeCode';

    /// على الموبايل: بدون Expanded + ListView داخل الـ drawer — على Android غالبًا
    /// ما يعطي ارتفاعًا صفريًا فيُرسم لون السطح فقط (رمادي) من غير عناصر.
    Widget navSection() {
      final futureBlock = FutureBuilder<String?>(
        future: tokens.getAccessToken(),
        builder: (context, snap) {
          final hasAuth = (snap.data ?? '').isNotEmpty;
          if (!hasAuth) {
            final items = [OfficeShell._items.first];
            return inDrawer
                ? _OfficeNavColumn(
                    officeCode: officeCode,
                    current: current,
                    items: items,
                    onBeforeNavigate: onCloseDrawer,
                  )
                : _NavList(
                    officeCode: officeCode,
                    current: current,
                    items: items,
                    onBeforeNavigate: onCloseDrawer,
                  );
          }
          return FutureBuilder<UserPermissionsDto>(
            future: permsApi.myPermissions(),
            builder: (context, ps) {
              if (ps.connectionState != ConnectionState.done) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: inDrawer ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'جارٍ تحميل القائمة…',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (inDrawer)
                      _OfficeNavColumn(
                        officeCode: officeCode,
                        current: current,
                        items: [OfficeShell._items.first],
                        onBeforeNavigate: onCloseDrawer,
                      )
                    else
                      Expanded(
                        child: _NavList(
                          officeCode: officeCode,
                          current: current,
                          items: [OfficeShell._items.first],
                          onBeforeNavigate: onCloseDrawer,
                        ),
                      ),
                  ],
                );
              }

              if (ps.hasError || !ps.hasData) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: inDrawer ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'تعذر تحميل الصلاحيات — سيتم عرض قائمة مبسطة.',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                    if (inDrawer)
                      _OfficeNavColumn(
                        officeCode: officeCode,
                        current: current,
                        items: [OfficeShell._items.first],
                        onBeforeNavigate: onCloseDrawer,
                      )
                    else
                      Expanded(
                        child: _NavList(
                          officeCode: officeCode,
                          current: current,
                          items: [OfficeShell._items.first],
                          onBeforeNavigate: onCloseDrawer,
                        ),
                      ),
                  ],
                );
              }

              final keys = ps.data!.permissions.toSet();
              var base = OfficeShell._items
                  .where((i) => _allowNav(i.segment, keys))
                  .toList();
              if (base.isEmpty) {
                base = [OfficeShell._items.first];
              }
              return FutureBuilder<MeDto>(
                future: meApi.me(),
                builder: (context, ms) {
                  final role = ms.data?.role;
                  final items = base
                      .where(
                        (i) =>
                            i.segment != 'subscription' ||
                            role == 'office_owner',
                      )
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: inDrawer ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      if (role != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Text(
                            'دورك: ${roleLabelAr(role)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      if (inDrawer)
                        _OfficeNavColumn(
                          officeCode: officeCode,
                          current: current,
                          items: items,
                          onBeforeNavigate: onCloseDrawer,
                        )
                      else
                        Expanded(
                          child: _NavList(
                            officeCode: officeCode,
                            current: current,
                            items: items,
                            onBeforeNavigate: onCloseDrawer,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      );

      if (inDrawer) return futureBlock;
      return Expanded(child: futureBlock);
    }

    final drawerTop = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gavel, color: Colors.white, size: 28),
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
            final line = name != null && name.isNotEmpty
                ? 'مكتب المستشار $name'
                : 'مكتب المستشار ($officeCode)';
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
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                maxLines: 1,
              ),
            ),
            IconButton(
              tooltip: 'نسخ رابط المكتب',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: officeLink));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ رابط المكتب')),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];

    final footer = <Widget>[
      const Divider(color: Colors.white24, height: 1),
      ListTile(
        tileColor: Colors.transparent,
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(color: Colors.redAccent),
        ),
        onTap: () async {
          onCloseDrawer?.call();
          await AuthTokenStorage().clear();
          if (!context.mounted) return;
          context.go(TenantBuildConfig.isTenantApk ? '/login' : '/');
        },
      ),
      const SizedBox(height: 8),
    ];

    if (inDrawer) {
      return ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: 12,
        ),
        physics: const ClampingScrollPhysics(),
        children: [
          ...drawerTop,
          navSection(),
          ...footer,
        ],
      );
    }

    final sidebarColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...drawerTop,
        navSection(),
        ...footer,
      ],
    );

    return Material(
      color: AppColors.sidebar,
      child: SafeArea(
        child: SizedBox(width: width, child: sidebarColumn),
      ),
    );
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

Widget _buildOfficeNavTile(
  BuildContext context, {
  required String officeCode,
  required String current,
  required _OfficeNavItem item,
  VoidCallback? onBeforeNavigate,
}) {
  final selected = item.segment == current;
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? AppColors.sidebarActive : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          onBeforeNavigate?.call();
          context.go('/o/$officeCode/${item.segment}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// قائمة للـ drawer بدون ListView (ارتفاع طبيعي من المحتوى).
class _OfficeNavColumn extends StatelessWidget {
  const _OfficeNavColumn({
    required this.officeCode,
    required this.current,
    required this.items,
    this.onBeforeNavigate,
  });

  final String officeCode;
  final String current;
  final List<_OfficeNavItem> items;
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _buildOfficeNavTile(
              context,
              officeCode: officeCode,
              current: current,
              item: item,
              onBeforeNavigate: onBeforeNavigate,
            ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.officeCode,
    required this.current,
    required this.items,
    this.onBeforeNavigate,
  });

  final String officeCode;
  final String current;
  final List<_OfficeNavItem> items;
  final VoidCallback? onBeforeNavigate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.sidebar,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildOfficeNavTile(
          context,
          officeCode: officeCode,
          current: current,
          item: items[i],
          onBeforeNavigate: onBeforeNavigate,
        ),
      ),
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
          padding: const EdgeInsetsDirectional.only(
            start: 8,
            end: 20,
            top: 6,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: officeLink));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رابط المكتب')),
                    );
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryBlue.withValues(
                            alpha: 0.15,
                          ),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'في مكتب المستشار ${off.name}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'دورك: ${roleLabelAr(me.role)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlue.withValues(
                          alpha: 0.15,
                        ),
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
