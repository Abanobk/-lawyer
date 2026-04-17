import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/core/constants/plan_perm_labels.dart';
import 'package:lawyer_app/core/constants/plan_sidebar_perm_keys.dart';
import 'package:lawyer_app/core/responsive/layout_mode.dart';
import 'package:lawyer_app/core/widgets/content_canvas.dart';
import 'package:lawyer_app/core/widgets/plan_offer_card.dart';
import 'package:lawyer_app/core/widgets/promo_image_memory.dart';
import 'package:lawyer_app/data/api/admin_api.dart';
import 'package:lawyer_app/data/api/auth_api.dart';
import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/auth_token_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lawyer_app/data/api/permissions_api.dart';
import 'package:intl/intl.dart' as intl;

/// مدخل السوبر أدمن (FAB من الشاشة الرئيسية). الحماية الفعلية من الـ API.
class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _authApi = AuthApi();
  final _meApi = MeApi();
  final _storage = AuthTokenStorage();

  bool _loading = false;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _resumeIfTokenExists();
  }

  Future<void> _resumeIfTokenExists() async {
    final access = await _storage.getAccessToken();
    if (access == null || access.isEmpty) return;
    try {
      final me = await _meApi.me();
      if (!mounted) return;
      if (me.role == 'super_admin') {
        setState(() => _authed = true);
      } else {
        await _storage.clear();
      }
    } catch (_) {
      // token invalid/expired
      await _storage.clear();
    }
    if (!mounted) return;
    setState(() {}); // refresh UI
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || !email.contains('@') || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل البريد وكلمة المرور')));
      return;
    }
    setState(() => _loading = true);
    try {
      final tokens = await _authApi.login(email: email, password: pass);
      await _storage.saveTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
      final me = await _meApi.me();
      if (!mounted) return;
      if (me.role != 'super_admin') {
        await _storage.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية سوبر أدمن')));
        return;
      }
      setState(() => _authed = true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppLayout.isWebDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('سوبر أدمن'),
        actions: [
          if (_authed)
            TextButton(
              onPressed: () async {
                await _storage.clear();
                if (!mounted) return;
                setState(() => _authed = false);
              },
              child: const Text('خروج'),
            ),
        ],
      ),
      body: ContentCanvas(
        child: _authed
            // For super admin on desktop: use full width so right sidebar can stick to screen edge.
            ? const _SuperAdminDashboard()
            : Align(
                alignment: isDesktop ? Alignment.center : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: _LoginCard(email: _email, pass: _pass, loading: _loading, onSubmit: _submit),
                ),
              ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.email, required this.pass, required this.loading, required this.onSubmit});

  final TextEditingController email;
  final TextEditingController pass;
  final bool loading;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تسجيل دخول سوبر أدمن', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: pass,
              labelText: 'كلمة المرور',
              enabled: !loading,
              onSubmitted: (_) => loading ? null : onSubmit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: loading ? null : onSubmit,
              child: loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.labelText,
    required this.enabled,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          tooltip: _show ? 'إخفاء' : 'إظهار',
          onPressed: widget.enabled ? () => setState(() => _show = !_show) : null,
          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      enabled: widget.enabled,
      obscureText: !_show,
      onSubmitted: widget.onSubmitted,
    );
  }
}

class _SuperAdminDashboard extends StatefulWidget {
  const _SuperAdminDashboard();

  @override
  State<_SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

enum _AdminSection { offices, plans, packages, proofs, settings }

enum _AdminOfficePanel {
  dashboard,
  offices,
  trial,
  activeSubs,
  alerts,
  superAdmins,
}

class _SuperAdminDashboardState extends State<_SuperAdminDashboard> {
  final _meApi = MeApi();
  final _adminApi = AdminApi();
  final _proofFilesApi = AdminPaymentProofFilesApi();

  late Future<MeDto> _meFuture = _meApi.me();
  late final Future<List<AdminOfficeDto>> _officesFuture = _adminApi.listOffices();
  late Future<List<AdminPlanDto>> _plansFuture = _adminApi.listPlans();
  late Future<List<AdminPaymentProofDto>> _proofsFuture = _adminApi.listPaymentProofs(status: 'pending');
  late Future<AdminTrialAnalyticsDto> _trialAnalyticsFuture = _adminApi.trialAnalytics(days: 30);
  late Future<AdminSubscriptionsAnalyticsDto> _subsAnalyticsFuture = _adminApi.subscriptionsAnalytics(days: 30);
  int _chartDays = 30;
  late Future<AdminSubscriptionsSeriesDto> _subsSeriesFuture = _adminApi.subscriptionsSeries(days: _chartDays);
  late Future<AdminAlertsDto> _alertsFuture = _adminApi.alerts();
  late Future<List<AdminSuperAdminDto>> _superAdminsFuture = _adminApi.listSuperAdmins();

  final _currentPass = TextEditingController();
  final _newEmail = TextEditingController();
  final _newPass = TextEditingController();
  bool _saving = false;
  _AdminSection _section = _AdminSection.offices;
  _AdminOfficePanel _officePanel = _AdminOfficePanel.dashboard;
  bool _officesMenuExpanded = true;

  @override
  void dispose() {
    _currentPass.dispose();
    _newEmail.dispose();
    _newPass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cur = _currentPass.text;
    final email = _newEmail.text.trim();
    final pass = _newPass.text;
    if (cur.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب كلمة المرور الحالية')));
      return;
    }
    if (email.isEmpty && pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب بريد جديد أو كلمة مرور جديدة')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _adminApi.updateMyCredentials(
        currentPassword: cur,
        newEmail: email.isEmpty ? null : email,
        newPassword: pass.isEmpty ? null : pass,
      );
      if (!mounted) return;
      _currentPass.clear();
      _newEmail.clear();
      _newPass.clear();
      setState(() => _meFuture = _meApi.me());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات السوبر أدمن')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _navItem({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.22 : 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...? (trailing == null ? null : [trailing, const SizedBox(width: 8)]),
            SizedBox(
              width: 22,
              child: selected ? Icon(isRtl ? Icons.chevron_right : Icons.chevron_left, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  void _refreshAll() {
    setState(() {
      _plansFuture = _adminApi.listPlans();
      _proofsFuture = _adminApi.listPaymentProofs(status: 'pending');
      _meFuture = _meApi.me();
      _trialAnalyticsFuture = _adminApi.trialAnalytics(days: 30);
      _subsAnalyticsFuture = _adminApi.subscriptionsAnalytics(days: 30);
      _subsSeriesFuture = _adminApi.subscriptionsSeries(days: _chartDays);
      _alertsFuture = _adminApi.alerts();
      _superAdminsFuture = _adminApi.listSuperAdmins();
    });
  }

  Widget _buildOfficeContent() {
    switch (_officePanel) {
      case _AdminOfficePanel.dashboard:
        return Container(
          color: const Color(0xFFF3F5F9),
          child: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 950;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('لوحة التحكم', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 360, child: _TrialSummaryCard(future: _trialAnalyticsFuture)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardChartCard(
                              days: _chartDays,
                              future: _subsSeriesFuture,
                              onDaysChanged: (d) => setState(() {
                                _chartDays = d;
                                _subsSeriesFuture = _adminApi.subscriptionsSeries(days: _chartDays);
                              }),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _TrialSummaryCard(future: _trialAnalyticsFuture),
                      const SizedBox(height: 12),
                      _DashboardChartCard(
                        days: _chartDays,
                        future: _subsSeriesFuture,
                        onDaysChanged: (d) => setState(() {
                          _chartDays = d;
                          _subsSeriesFuture = _adminApi.subscriptionsSeries(days: _chartDays);
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _ActiveSubsCard(future: _subsAnalyticsFuture)),
                          const SizedBox(width: 12),
                          Expanded(child: _AlertsCard(future: _alertsFuture)),
                        ],
                      )
                    else ...[
                      _ActiveSubsCard(future: _subsAnalyticsFuture),
                      const SizedBox(height: 12),
                      _AlertsCard(future: _alertsFuture),
                    ],
                    const SizedBox(height: 12),
                    // Full details card (kept for deep inspection)
                    _TrialCard(
                      future: _trialAnalyticsFuture,
                      adminApi: _adminApi,
                      onTrialEdited: () => setState(() => _trialAnalyticsFuture = _adminApi.trialAnalytics(days: 30)),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      case _AdminOfficePanel.offices:
        return _OfficesTab(future: _officesFuture, adminApi: _adminApi);
      case _AdminOfficePanel.trial:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('التجربة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _TrialCard(
                future: _trialAnalyticsFuture,
                adminApi: _adminApi,
                onTrialEdited: () => setState(() => _trialAnalyticsFuture = _adminApi.trialAnalytics(days: 30)),
              ),
            ],
          ),
        );
      case _AdminOfficePanel.activeSubs:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الاشتراكات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _ActiveSubsCard(future: _subsAnalyticsFuture),
            ],
          ),
        );
      case _AdminOfficePanel.alerts:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تحذيرات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _AlertsCard(future: _alertsFuture),
            ],
          ),
        );
      case _AdminOfficePanel.superAdmins:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('المستخدمين', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _SuperAdminsCard(
                future: _superAdminsFuture,
                adminApi: _adminApi,
                onRefresh: () => setState(() => _superAdminsFuture = _adminApi.listSuperAdmins()),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final content = switch (_section) {
      _AdminSection.offices => _buildOfficeContent(),
      _AdminSection.plans => _PlansTab(
          future: _plansFuture,
          adminApi: _adminApi,
          onRefresh: () => setState(() => _plansFuture = _adminApi.listPlans()),
        ),
      _AdminSection.packages => _PackagesTab(
          future: _plansFuture,
          adminApi: _adminApi,
          onRefresh: () => setState(() => _plansFuture = _adminApi.listPlans()),
        ),
      _AdminSection.proofs => _ProofsTab(
          future: _proofsFuture,
          adminApi: _adminApi,
          filesApi: _proofFilesApi,
          onRefresh: (status) => setState(() => _proofsFuture = _adminApi.listPaymentProofs(status: status)),
        ),
      _AdminSection.settings => _SettingsTab(
          meFuture: _meFuture,
          currentPass: _currentPass,
          newEmail: _newEmail,
          newPass: _newPass,
          saving: _saving,
          onSave: _save,
        ),
    };

    final divider = Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 10), color: Colors.white.withValues(alpha: 0.18));
    final sidebar = Container(
      width: 270,
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A5F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'لوحة السوبر أدمن',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _refreshAll,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _navItem(
                    selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.dashboard,
                    onTap: () => setState(() {
                      _section = _AdminSection.offices;
                      _officePanel = _AdminOfficePanel.dashboard;
                      _officesMenuExpanded = true;
                    }),
                    icon: Icons.dashboard_outlined,
                    label: 'لوحة التحكم',
                  ),
                  _navItem(
                    selected: _section == _AdminSection.plans,
                    onTap: () => setState(() {
                      _section = _AdminSection.plans;
                      _officesMenuExpanded = false;
                    }),
                    icon: Icons.view_module_outlined,
                    label: 'إدارة الباقات',
                  ),
                  _navItem(
                    selected: _section == _AdminSection.packages,
                    onTap: () => setState(() {
                      _section = _AdminSection.packages;
                      _officesMenuExpanded = false;
                    }),
                    icon: Icons.local_offer_outlined,
                    label: 'الباقات',
                  ),
                  _navItem(
                    selected: _section == _AdminSection.proofs,
                    onTap: () => setState(() {
                      _section = _AdminSection.proofs;
                      _officesMenuExpanded = false;
                    }),
                    icon: Icons.payments_outlined,
                    label: 'التحويلات',
                  ),
                  _navItem(
                    selected: _section == _AdminSection.settings,
                    onTap: () => setState(() {
                      _section = _AdminSection.settings;
                      _officesMenuExpanded = false;
                    }),
                    icon: Icons.settings_outlined,
                    label: 'إعدادات',
                  ),
                  divider,
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: AbsorbPointer(
                      absorbing: _section != _AdminSection.offices,
                      child: Opacity(
                        opacity: _section == _AdminSection.offices ? 1.0 : 0.65,
                        child: ExpansionTile(
                          initiallyExpanded: _officesMenuExpanded,
                          onExpansionChanged: (v) => setState(() => _officesMenuExpanded = v),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
                          collapsedIconColor: Colors.white,
                          iconColor: Colors.white,
                          title: const Text('المكاتب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                          children: [
                            FutureBuilder<List<AdminOfficeDto>>(
                              future: _officesFuture,
                              builder: (context, snap) {
                                final n = (snap.data ?? const <AdminOfficeDto>[]).length;
                                return _navItem(
                                  selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.offices,
                                  onTap: () => setState(() {
                                    _section = _AdminSection.offices;
                                    _officePanel = _AdminOfficePanel.offices;
                                  }),
                                  icon: Icons.apartment_outlined,
                                  label: 'قائمة المكاتب',
                                  trailing: _badge('$n'),
                                );
                              },
                            ),
                            FutureBuilder<AdminTrialAnalyticsDto>(
                              future: _trialAnalyticsFuture,
                              builder: (context, snapTrial) {
                                final n = snapTrial.data?.totalTrialOffices;
                                return _navItem(
                                  selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.trial,
                                  onTap: () => setState(() {
                                    _section = _AdminSection.offices;
                                    _officePanel = _AdminOfficePanel.trial;
                                  }),
                                  icon: Icons.hourglass_bottom,
                                  label: 'التجربة',
                                  trailing: n == null ? null : _badge('$n'),
                                );
                              },
                            ),
                            FutureBuilder<AdminSubscriptionsAnalyticsDto>(
                              future: _subsAnalyticsFuture,
                              builder: (context, snapSubs) {
                                final n = snapSubs.data?.totalActiveOffices;
                                return _navItem(
                                  selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.activeSubs,
                                  onTap: () => setState(() {
                                    _section = _AdminSection.offices;
                                    _officePanel = _AdminOfficePanel.activeSubs;
                                  }),
                                  icon: Icons.credit_card_outlined,
                                  label: 'الاشتراكات',
                                  trailing: n == null ? null : _badge('$n'),
                                );
                              },
                            ),
                            FutureBuilder<AdminAlertsDto>(
                              future: _alertsFuture,
                              builder: (context, snapA) {
                                final a = snapA.data;
                                final total = a == null ? null : (a.trialExpiring3d + a.activeExpiring7d + a.expiredOrInactive);
                                return _navItem(
                                  selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.alerts,
                                  onTap: () => setState(() {
                                    _section = _AdminSection.offices;
                                    _officePanel = _AdminOfficePanel.alerts;
                                  }),
                                  icon: Icons.notifications_active_outlined,
                                  label: 'تحذيرات',
                                  trailing: total == null ? null : _badge('$total'),
                                );
                              },
                            ),
                            FutureBuilder<List<AdminSuperAdminDto>>(
                              future: _superAdminsFuture,
                              builder: (context, snapU) {
                                final n = (snapU.data ?? const <AdminSuperAdminDto>[]).length;
                                return _navItem(
                                  selected: _section == _AdminSection.offices && _officePanel == _AdminOfficePanel.superAdmins,
                                  onTap: () => setState(() {
                                    _section = _AdminSection.offices;
                                    _officePanel = _AdminOfficePanel.superAdmins;
                                  }),
                                  icon: Icons.manage_accounts_outlined,
                                  label: 'المستخدمين والصلاحيات',
                                  trailing: _badge('$n'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اضغط عنصر لعرض التفاصيل',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: isRtl
          ? [
              // In RTL, first child renders on the right.
              sidebar,
              const SizedBox(width: 10),
              Expanded(child: content),
            ]
          : [
              Expanded(child: content),
              const SizedBox(width: 10),
              sidebar,
            ],
    );
  }
}

class _PlansTab extends StatefulWidget {
  const _PlansTab({required this.future, required this.adminApi, required this.onRefresh});
  final Future<List<AdminPlanDto>> future;
  final AdminApi adminApi;
  final VoidCallback onRefresh;

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController();
  final _link = TextEditingController();
  final _packageKey = TextEditingController();
  final _maxUsers = TextEditingController();
  final _price6 = TextEditingController();
  final _days6 = TextEditingController();
  final _link6 = TextEditingController();
  final _selectedPermKeys = <String>[];
  bool _saving = false;
  final _promoFilesApi = AdminPlanPromoFilesApi();
  PlatformFile? _packagePromoFile;
  late Future<List<PermissionCatalogItemDto>> _permsFuture;

  @override
  void initState() {
    super.initState();
    _maxUsers.text = '3';
    _days.text = '90';
    _days6.text = '180';
    _packageKey.text = '';
    _permsFuture = widget.adminApi.permissionsCatalog();
    _selectedPermKeys.addAll(kDefaultPlanSidebarPermKeys);
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    _link.dispose();
    _packageKey.dispose();
    _maxUsers.dispose();
    _price6.dispose();
    _days6.dispose();
    _link6.dispose();
    super.dispose();
  }

  Future<void> _pickPackagePromo() async {
    try {
      final res = await FilePicker.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      final file = (res?.files.isNotEmpty ?? false) ? res!.files.first : null;
      if (file == null) return;
      if (file.bytes == null || file.bytes!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف غير متاح للرفع')));
        return;
      }
      setState(() => _packagePromoFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح اختيار الملفات: $e')));
    }
  }

  Future<void> _confirmDeactivatePlan(AdminPlanDto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعطيل الباقة؟'),
        content: Text('«${p.name}» — لن تظهر للمستأجرين كخيار اشتراك. الاشتراكات الحالية لا تتأثر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تعطيل')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.adminApi.deletePlan(p.id);
      if (!mounted) return;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل الباقة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
    }
  }

  Future<void> _openEditPlan(AdminPlanDto p) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditPlanDialog(
        plan: p,
        adminApi: widget.adminApi,
        permsFuture: _permsFuture,
        onSuccess: () {
          Navigator.pop(ctx);
          widget.onRefresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
          }
        },
      ),
    );
  }

  Future<void> _createPackageWithOptions() async {
    final packageName = _name.text.trim();
    final packageKeyVal = _packageKey.text.trim().isEmpty ? packageName : _packageKey.text.trim();
    final maxUsersVal = int.tryParse(_maxUsers.text.trim());

    final price3 = double.tryParse(_price.text.trim());
    final days3 = int.tryParse(_days.text.trim());
    final link3 = _link.text.trim();

    final price6 = double.tryParse(_price6.text.trim());
    final days6 = int.tryParse(_days6.text.trim());
    final link6 = _link6.text.trim();

    if (packageName.length < 2 || maxUsersVal == null || maxUsersVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم الباقة وعدد المستخدمين بشكل صحيح')));
      return;
    }
    if (price3 == null || price3 <= 0 || days3 == null || days3 <= 0 || link3.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل خيار 3 شهور (سعر/مدة/رابط) بشكل صحيح')));
      return;
    }
    if (price6 == null || price6 <= 0 || days6 == null || days6 <= 0 || link6.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل خيار 6 شهور (سعر/مدة/رابط) بشكل صحيح')));
      return;
    }

    final allowedPermKeys = List<String>.from(
      _selectedPermKeys.isEmpty ? kDefaultPlanSidebarPermKeys : _selectedPermKeys,
    );

    setState(() => _saving = true);
    try {
      final plans = <AdminPlanDto>[];
      final name3 = '$packageName — $days3 يوم';
      final name6 = '$packageName — $days6 يوم';

      final p3 = await widget.adminApi.createPlan(
        name: name3,
        priceCents: (price3 * 100).round(),
        durationDays: days3,
        instapayLink: link3,
        packageKey: packageKeyVal,
        packageName: packageName,
        maxUsers: maxUsersVal,
        allowedPermKeys: allowedPermKeys,
      );
      plans.add(p3);

      final p6 = await widget.adminApi.createPlan(
        name: name6,
        priceCents: (price6 * 100).round(),
        durationDays: days6,
        instapayLink: link6,
        packageKey: packageKeyVal,
        packageName: packageName,
        maxUsers: maxUsersVal,
        allowedPermKeys: allowedPermKeys,
      );
      plans.add(p6);

      if (_packagePromoFile != null) {
        for (final p in plans) {
          await _promoFilesApi.uploadPromoImage(planId: p.id, file: _packagePromoFile!);
        }
      }

      if (!mounted) return;
      _name.clear();
      _packageKey.clear();
      _maxUsers.text = '3';
      _price.clear();
      _days.text = '90';
      _link.clear();
      _price6.clear();
      _days6.text = '180';
      _link6.clear();
      _selectedPermKeys
        ..clear()
        ..addAll(kDefaultPlanSidebarPermKeys);
      _packagePromoFile = null;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الباقة + خيارات الدفع')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إنشاء الباقة: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('إدارة الباقات', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(onPressed: widget.onRefresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),
            Text('الباقات الحالية', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: FutureBuilder<List<AdminPlanDto>>(
                future: widget.future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snap.hasError) return Center(child: Text('تعذر التحميل: ${snap.error}'));
                  final plans = snap.data ?? const <AdminPlanDto>[];
                  if (plans.isEmpty) return const Center(child: Text('لا توجد باقات بعد'));
                  return ListView.separated(
                    itemCount: plans.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = plans[i];
                      final price = (p.priceCents / 100).toStringAsFixed(0);
                      return ListTile(
                        dense: true,
                        title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$price ج — ${p.durationDays} يوم — ${p.isActive ? 'نشط' : 'معطّل'}${p.packageKey != null && p.packageKey!.trim().isNotEmpty ? ' — ${p.packageKey}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _saving ? null : () => _openEditPlan(p),
                            ),
                            IconButton(
                              tooltip: 'تعطيل',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _saving || !p.isActive ? null : () => _confirmDeactivatePlan(p),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('إضافة باقة (مستخدمين + موديولات + 3/6 شهور)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _packageKey,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'package_key (اختياري للتجميع)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'اسم الباقة (يظهر للمستاجر)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxUsers,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'عدد المستخدمين (يشمل office_owner)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'صلاحيات الوحدات (افتراضي: ${kDefaultPlanSidebarPermKeys.length} = عناصر القائمة بدون «الاشتراك»). يمكنك تعديل الاختيار.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<PermissionCatalogItemDto>>(
                      future: _permsFuture,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        if (snap.hasError) return Text('تعذر تحميل صلاحيات: ${snap.error}');
                        final items = snap.data ?? const <PermissionCatalogItemDto>[];
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: items.map((it) {
                            final selected = _selectedPermKeys.contains(it.key);
                            return FilterChip(
                              label: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              selected: selected,
                              onSelected: _saving
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v) {
                                          _selectedPermKeys.add(it.key);
                                        } else {
                                          _selectedPermKeys.remove(it.key);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('خيارات الدفع', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _days,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: '3 شهور (أيام)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _price,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'سعر 3 شهور'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _link,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'رابط إنستاباي (3 شهور)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _days6,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: '6 شهور (أيام)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _price6,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'سعر 6 شهور'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _link6,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'رابط إنستاباي (6 شهور)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _packagePromoFile?.name == null ? 'بدون صورة دعاية' : 'تم اختيار صورة: ${_packagePromoFile!.name}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: !_saving ? _pickPackagePromo : null,
                          child: const Text('اختيار صورة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _createPackageWithOptions,
                      child: _saving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ الباقة + خياراتها'),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPlanDialog extends StatefulWidget {
  const _EditPlanDialog({
    required this.plan,
    required this.adminApi,
    required this.permsFuture,
    required this.onSuccess,
  });

  final AdminPlanDto plan;
  final AdminApi adminApi;
  final Future<List<PermissionCatalogItemDto>> permsFuture;
  final VoidCallback onSuccess;

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _days;
  late final TextEditingController _link;
  late final TextEditingController _packageKey;
  late final TextEditingController _packageName;
  late final TextEditingController _maxUsers;
  late List<String> _permKeys;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p.name);
    _price = TextEditingController(text: (p.priceCents / 100).toStringAsFixed(2));
    _days = TextEditingController(text: '${p.durationDays}');
    _link = TextEditingController(text: p.instapayLink ?? '');
    _packageKey = TextEditingController(text: p.packageKey ?? '');
    _packageName = TextEditingController(text: p.packageName ?? '');
    _maxUsers = TextEditingController(text: p.maxUsers == null ? '' : '${p.maxUsers}');
    _permKeys = List<String>.from(p.allowedPermKeys ?? kDefaultPlanSidebarPermKeys);
    _active = p.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    _link.dispose();
    _packageKey.dispose();
    _packageName.dispose();
    _maxUsers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    final days = int.tryParse(_days.text.trim());
    final maxU = int.tryParse(_maxUsers.text.trim());
    if (name.length < 2 || price == null || price <= 0 || days == null || days <= 0 || maxU == null || maxU <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحقق من الاسم والسعر والمدة وحد المستخدمين')));
      return;
    }
    final perms = _permKeys.isEmpty ? List<String>.from(kDefaultPlanSidebarPermKeys) : List<String>.from(_permKeys);
    setState(() => _busy = true);
    try {
      await widget.adminApi.updatePlan(
        widget.plan.id,
        name: name,
        priceCents: (price * 100).round(),
        durationDays: days,
        instapayLink: _link.text.trim().isEmpty ? '' : _link.text.trim(),
        packageKey: _packageKey.text.trim().isEmpty ? '' : _packageKey.text.trim(),
        packageName: _packageName.text.trim().isEmpty ? '' : _packageName.text.trim(),
        maxUsers: maxU,
        allowedPermKeys: perms,
        isActive: _active,
      );
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تعديل باقة #${widget.plan.id}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الباقة')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      decoration: const InputDecoration(labelText: 'السعر (ج)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _days,
                      decoration: const InputDecoration(labelText: 'المدة (يوم)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _link, decoration: const InputDecoration(labelText: 'رابط إنستاباي')),
              const SizedBox(height: 8),
              TextField(controller: _packageKey, decoration: const InputDecoration(labelText: 'package_key')),
              const SizedBox(height: 8),
              TextField(controller: _packageName, decoration: const InputDecoration(labelText: 'package_name')),
              const SizedBox(height: 8),
              TextField(controller: _maxUsers, decoration: const InputDecoration(labelText: 'حد المستخدمين'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('باقة نشطة'),
                value: _active,
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _active = v);
                      },
              ),
              const SizedBox(height: 8),
              Text('وحدات التحكم', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              FutureBuilder<List<PermissionCatalogItemDto>>(
                future: widget.permsFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final items = snap.data ?? const <PermissionCatalogItemDto>[];
                  return Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: items.map((it) {
                      final sel = _permKeys.contains(it.key);
                      return FilterChip(
                        label: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        selected: sel,
                        onSelected: _busy
                            ? null
                            : (v) {
                                setState(() {
                                  if (v) {
                                    _permKeys.add(it.key);
                                  } else {
                                    _permKeys.remove(it.key);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

String _adminPlanGroupKey(AdminPlanDto p) {
  final pk = p.packageKey?.trim() ?? '';
  if (pk.isNotEmpty) return 'k:$pk';
  final pn = p.packageName?.trim() ?? '';
  if (pn.isNotEmpty) return 'n:$pn';
  return 'u:${p.id}';
}

List<List<AdminPlanDto>> _groupAdminPlansByPackage(List<AdminPlanDto> plans, {int maxGroups = 6}) {
  final active = plans.where((p) => p.isActive).toList();
  final map = <String, List<AdminPlanDto>>{};
  for (final p in active) {
    map.putIfAbsent(_adminPlanGroupKey(p), () => []).add(p);
  }
  for (final g in map.values) {
    g.sort((a, b) {
      final c = a.priceCents.compareTo(b.priceCents);
      if (c != 0) return c;
      return a.durationDays.compareTo(b.durationDays);
    });
  }
  final groups = map.values.toList()..sort((a, b) => a.first.priceCents.compareTo(b.first.priceCents));
  if (groups.length > maxGroups) return groups.take(maxGroups).toList();
  return groups;
}

AdminPlanDto _adminPlanForPromoImage(List<AdminPlanDto> group) {
  for (final p in group) {
    final path = p.promoImagePath?.trim() ?? '';
    if (path.isNotEmpty) return p;
  }
  return group.first;
}

class _PackagesTab extends StatefulWidget {
  const _PackagesTab({required this.future, required this.adminApi, required this.onRefresh});
  final Future<List<AdminPlanDto>> future;
  final AdminApi adminApi;
  final VoidCallback onRefresh;

  @override
  State<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<_PackagesTab> {
  final _promoApi = AdminPlanPromoFilesApi();
  final Map<int, Future<Uint8List?>> _promoBytes = {};
  late final Future<List<PermissionCatalogItemDto>> _permsFuture = widget.adminApi.permissionsCatalog();

  Future<void> _confirmDeactivatePlan(AdminPlanDto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعطيل الباقة؟'),
        content: Text('«${p.name}» — لن تظهر للمستأجرين كخيار اشتراك. الاشتراكات الحالية لا تتأثر.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تعطيل')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.adminApi.deletePlan(p.id);
      if (!mounted) return;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل الباقة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
    }
  }

  Future<void> _openEditPlan(AdminPlanDto p) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditPlanDialog(
        plan: p,
        adminApi: widget.adminApi,
        permsFuture: _permsFuture,
        onSuccess: () {
          Navigator.pop(ctx);
          widget.onRefresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
          }
        },
      ),
    );
  }

  Widget _promoImage(AdminPlanDto p) {
    if (p.promoImagePath == null || p.promoImagePath!.trim().isEmpty) {
      return Container(
        color: Colors.grey.withValues(alpha: 0.12),
        child: const Center(child: Icon(Icons.image_outlined, size: 48)),
      );
    }
    final fut = _promoBytes.putIfAbsent(
      p.id,
      () async {
        try {
          final (bytes, _) = await _promoApi.downloadPromo(p.id);
          return bytes;
        } catch (_) {
          return null;
        }
      },
    );
    return FutureBuilder<Uint8List?>(
      future: fut,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (!s.hasData || s.data == null) {
          return Container(
            color: Colors.grey.withValues(alpha: 0.12),
            child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
          );
        }
        return PromoImageMemory(bytes: s.data!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('معاينة الباقات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(onPressed: widget.onRefresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عرض الباقات المفعّلة كما يظهر للمستأجر (حد أقصى 6).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AdminPlanDto>>(
                future: widget.future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('تعذر تحميل الباقات: ${snap.error}'));
                  final all = snap.data ?? const <AdminPlanDto>[];
                  final groups = _groupAdminPlansByPackage(all);
                  if (groups.isEmpty) return const Center(child: Text('لا توجد باقات مفعّلة'));

                  return LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cross = w > 1100 ? 3 : (w > 640 ? 2 : 1);
                      const gap = 16.0;
                      final itemW = (w - gap * (cross - 1)) / cross;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final group in groups)
                              SizedBox(
                                width: itemW,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PlanOfferCard(
                                      title: (group.first.packageName ?? '').trim().isNotEmpty
                                          ? group.first.packageName!.trim()
                                          : group.first.name,
                                      sharedDetailWidgets: [
                                        if (group.first.maxUsers != null)
                                          Text('حتى: ${group.first.maxUsers} مستخدم', style: Theme.of(context).textTheme.bodyMedium),
                                        if (group.first.maxUsers != null) const SizedBox(height: 4),
                                        Builder(
                                          builder: (ctx) => controlUnitsCountLine(ctx, group.first.allowedPermKeys),
                                        ),
                                      ],
                                      packageKeyText: group.first.packageKey,
                                      footerHint: () {
                                        final optionsLines = group
                                            .map(
                                              (p) =>
                                                  '• ${(p.priceCents / 100).toStringAsFixed(0)} ج / ${p.durationDays} يوم — ${p.name}${p.instapayLink != null && p.instapayLink!.trim().isNotEmpty ? '' : ' (بدون رابط إنستاباي)'}',
                                            )
                                            .join('\n');
                                        final linksOk = group.every((p) => p.instapayLink != null && p.instapayLink!.trim().isNotEmpty);
                                        return 'معاينة كما يظهر للمستأجر (خيارات الاشتراك):\n$optionsLines${linksOk ? '' : '\nتنبيه: راجع روابط إنستاباي لكل خيار.'}';
                                      }(),
                                      image: _promoImage(_adminPlanForPromoImage(group)),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('إدارة الخطط', style: Theme.of(context).textTheme.labelLarge),
                                    const SizedBox(height: 6),
                                    for (final p in group)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Material(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: const EdgeInsetsDirectional.only(start: 8, end: 4, top: 4, bottom: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${(p.priceCents / 100).toStringAsFixed(0)} ج · ${p.durationDays} يوم · #${p.id}',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'تعديل',
                                                icon: const Icon(Icons.edit_outlined, size: 20),
                                                onPressed: () => _openEditPlan(p),
                                              ),
                                              IconButton(
                                                tooltip: 'تعطيل',
                                                icon: const Icon(Icons.delete_outline, size: 20),
                                                onPressed: p.isActive ? () => _confirmDeactivatePlan(p) : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofsTab extends StatefulWidget {
  const _ProofsTab({required this.future, required this.adminApi, required this.filesApi, required this.onRefresh});
  final Future<List<AdminPaymentProofDto>> future;
  final AdminApi adminApi;
  final AdminPaymentProofFilesApi filesApi;
  final void Function(String status) onRefresh;

  @override
  State<_ProofsTab> createState() => _ProofsTabState();
}

class _ProofsTabState extends State<_ProofsTab> {
  String _status = 'pending';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('تحويلات إنستاباي', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
                    DropdownMenuItem(value: 'approved', child: Text('تمت الموافقة')),
                    DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _status = v);
                          widget.onRefresh(v);
                        },
                ),
                IconButton(
                  onPressed: _busy ? null : () => widget.onRefresh(_status),
                  tooltip: 'تحديث',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AdminPaymentProofDto>>(
                future: widget.future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('تعذر تحميل التحويلات: ${snap.error}'));
                  final proofs = snap.data ?? const <AdminPaymentProofDto>[];
                  if (proofs.isEmpty) return const Center(child: Text('لا توجد تحويلات'));
                  return ListView.separated(
                    itemCount: proofs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = proofs[i];
                      return ListTile(
                        title: Text('إثبات #${p.id} — مكتب #${p.officeId}'),
                        subtitle: Text('الحالة: ${p.status} — خطة: ${p.planId ?? "—"}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openProof(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProof(AdminPaymentProofDto p) async {
    setState(() => _busy = true);
    try {
      final (bytes, contentType) = await widget.filesApi.downloadProof(p.id);
      if (!mounted) return;
      final decision = TextEditingController(text: p.decisionNotes ?? '');
      final isPdf = (contentType ?? '').contains('pdf');
      final canReview = p.status == 'pending';
      final res = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('إثبات #${p.id}'),
          content: SizedBox(
            width: 900,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isPdf)
                  const Text('ملف PDF (المعاينة داخل التطبيق غير مدعومة).')
                else
                  Image.memory(bytes, fit: BoxFit.contain),
                const SizedBox(height: 12),
                TextField(
                  controller: decision,
                  decoration: const InputDecoration(labelText: 'ملاحظات القرار (اختياري)'),
                  minLines: 2,
                  maxLines: 4,
                  enabled: canReview,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'close'), child: const Text('إغلاق')),
            if (canReview) ...[
              TextButton(onPressed: () => Navigator.pop(context, 'reject:${decision.text}'), child: const Text('رفض')),
              FilledButton(onPressed: () => Navigator.pop(context, 'approve:${decision.text}'), child: const Text('موافقة')),
            ],
          ],
        ),
      );
      decision.dispose();
      if (res == null || res == 'close') return;
      if (res.startsWith('approve:')) {
        final notes = res.substring('approve:'.length).trim();
        await widget.adminApi.approvePaymentProof(p.id, decisionNotes: notes.isEmpty ? null : notes);
      } else if (res.startsWith('reject:')) {
        final notes = res.substring('reject:'.length).trim();
        await widget.adminApi.rejectPaymentProof(p.id, decisionNotes: notes.isEmpty ? null : notes);
      }
      widget.onRefresh(_status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر فتح الإثبات: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

Widget _adminDetailRow(BuildContext context, IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SelectableText(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SubUrgencyStyle {
  const _SubUrgencyStyle({required this.background, required this.border, required this.accent, required this.hint});
  final Color background;
  final Color border;
  final Color accent;
  final String hint;
}

_SubUrgencyStyle _urgencyForEnd(DateTime endAtUtc, String status) {
  final now = DateTime.now();
  final end = endAtUtc.toLocal();
  if (status == 'expired' || status == 'cancelled' || end.isBefore(now)) {
    return const _SubUrgencyStyle(
      background: Color(0xFFFFEBEE),
      border: Color(0xFFE57373),
      accent: Color(0xFFB71C1C),
      hint: 'منتهٍ',
    );
  }
  final dayEnd = DateTime(end.year, end.month, end.day);
  final dayNow = DateTime(now.year, now.month, now.day);
  final days = dayEnd.difference(dayNow).inDays;
  if (days <= 0) {
    return const _SubUrgencyStyle(
      background: Color(0xFFFFEBEE),
      border: Color(0xFFE57373),
      accent: Color(0xFFB71C1C),
      hint: 'ينتهي اليوم أو انتهى',
    );
  }
  if (days <= 3) {
    return _SubUrgencyStyle(
      background: const Color(0xFFFFE0B2),
      border: const Color(0xFFFF9800),
      accent: const Color(0xFFE65100),
      hint: 'ينتهي خلال $days أيام',
    );
  }
  if (days <= 7) {
    return const _SubUrgencyStyle(
      background: Color(0xFFFFF9C4),
      border: Color(0xFFFFCA28),
      accent: Color(0xFFF57F17),
      hint: 'أقل من أسبوع',
    );
  }
  if (days <= 30) {
    return _SubUrgencyStyle(
      background: const Color(0xFFE8F5E9),
      border: const Color(0xFF66BB6A),
      accent: const Color(0xFF1B5E20),
      hint: '$days يوم متبقية',
    );
  }
  return _SubUrgencyStyle(
    background: const Color(0xFFE3F2FD),
    border: const Color(0xFF42A5F5),
    accent: const Color(0xFF0D47A1),
    hint: '$days يوم متبقية',
  );
}

bool _sameOfficeIds(List<AdminOfficeDto> a, List<AdminOfficeDto> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _OfficesSubscriptionListPanel extends StatefulWidget {
  const _OfficesSubscriptionListPanel({
    required this.offices,
    required this.adminApi,
    required this.selectedOfficeId,
    required this.refreshToken,
    this.onSelect,
  });

  final List<AdminOfficeDto> offices;
  final AdminApi adminApi;
  final int? selectedOfficeId;
  final ValueChanged<int>? onSelect;
  final int refreshToken;

  @override
  State<_OfficesSubscriptionListPanel> createState() => _OfficesSubscriptionListPanelState();
}

class _OfficesSubscriptionListPanelState extends State<_OfficesSubscriptionListPanel> {
  late Future<List<AdminSubscriptionDto?>> _subsFuture;

  @override
  void initState() {
    super.initState();
    _subsFuture = _fetch();
  }

  Future<List<AdminSubscriptionDto?>> _fetch() {
    return Future.wait(
      widget.offices.map((o) async {
        try {
          return await widget.adminApi.getSubscription(o.id);
        } catch (_) {
          return null;
        }
      }),
    );
  }

  @override
  void didUpdateWidget(covariant _OfficesSubscriptionListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final officesChanged = !_sameOfficeIds(oldWidget.offices, widget.offices);
    final tokenChanged = oldWidget.refreshToken != widget.refreshToken;
    if (officesChanged || tokenChanged) {
      setState(() {
        _subsFuture = _fetch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminSubscriptionDto?>>(
      future: _subsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Center(child: Text('تعذر تحميل الاشتراكات: ${snap.error}'));
        }
        final subs = snap.data ?? List<AdminSubscriptionDto?>.filled(widget.offices.length, null);
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 520;
            final child = wide
                ? GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: widget.offices.length,
                    itemBuilder: (context, i) => _officeCard(context, widget.offices[i], subs[i]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: widget.offices.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _officeCard(context, widget.offices[i], subs[i]),
                    ),
                  );
            return child;
          },
        );
      },
    );
  }

  Widget _officeCard(BuildContext context, AdminOfficeDto o, AdminSubscriptionDto? sub) {
    final selected = widget.onSelect != null && widget.selectedOfficeId == o.id;
    final st = sub == null
        ? const _SubUrgencyStyle(
            background: Color(0xFFF5F5F5),
            border: Color(0xFFBDBDBD),
            accent: Color(0xFF616161),
            hint: 'لا بيانات',
          )
        : _urgencyForEnd(sub.endAt, sub.status);
    final df = intl.DateFormat.yMMMd().add_Hm();
    return Material(
      color: st.background,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onSelect == null ? null : () => widget.onSelect!(o.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: st.border, width: selected ? 2.8 : 1.2),
            boxShadow: selected
                ? [BoxShadow(color: st.accent.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      o.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      st.hint,
                      style: TextStyle(color: st.accent, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('كود: ${o.code}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
              if (o.phone != null && o.phone!.trim().isNotEmpty)
                Text(
                  'جوال: ${o.phone}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w600),
                ),
              Text('حالة المكتب: ${o.status}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
              const Spacer(),
              if (sub != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${sub.status} — ينتهي ${df.format(sub.endAt.toLocal())}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficesTab extends StatefulWidget {
  const _OfficesTab({required this.future, required this.adminApi});
  final Future<List<AdminOfficeDto>> future;
  final AdminApi adminApi;

  @override
  State<_OfficesTab> createState() => _OfficesTabState();
}

class _OfficesTabState extends State<_OfficesTab> {
  int? _selectedOfficeId;
  AdminSubscriptionDto? _sub;
  bool _loading = false;
  bool _showAllOffices = false;
  /// يزيد بعد التعديل أو التحديث لإعادة جلب ألوان الانتهاء للمكاتب.
  int _officeSubsRefreshToken = 0;
  late Future<AdminTrialAnalyticsDto> _trialAnalyticsFuture;
  late Future<AdminSubscriptionsAnalyticsDto> _subsAnalyticsFuture;
  late Future<AdminAlertsDto> _alertsFuture;
  late Future<List<AdminSuperAdminDto>> _superAdminsFuture;

  @override
  void initState() {
    super.initState();
    _trialAnalyticsFuture = widget.adminApi.trialAnalytics(days: 30);
    _subsAnalyticsFuture = widget.adminApi.subscriptionsAnalytics(days: 30);
    _alertsFuture = widget.adminApi.alerts();
    _superAdminsFuture = widget.adminApi.listSuperAdmins();
  }

  Future<void> _loadSub(int officeId) async {
    setState(() {
      _selectedOfficeId = officeId;
      _loading = true;
      _sub = null;
    });
    try {
      final s = await widget.adminApi.getSubscription(officeId);
      if (!mounted) return;
      setState(() => _sub = s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshAll() {
    setState(() {
      _officeSubsRefreshToken++;
      _trialAnalyticsFuture = widget.adminApi.trialAnalytics(days: 30);
      _subsAnalyticsFuture = widget.adminApi.subscriptionsAnalytics(days: 30);
      _alertsFuture = widget.adminApi.alerts();
      _superAdminsFuture = widget.adminApi.listSuperAdmins();
    });
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('لوحة التحكم', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _TrialCard(
            future: _trialAnalyticsFuture,
            adminApi: widget.adminApi,
            onTrialEdited: () => setState(() => _trialAnalyticsFuture = widget.adminApi.trialAnalytics(days: 30)),
          ),
          const SizedBox(height: 12),
          _ActiveSubsCard(future: _subsAnalyticsFuture),
          const SizedBox(height: 12),
          _AlertsCard(future: _alertsFuture),
          const SizedBox(height: 12),
          _SuperAdminsCard(
            future: _superAdminsFuture,
            adminApi: widget.adminApi,
            onRefresh: () => setState(() => _superAdminsFuture = widget.adminApi.listSuperAdmins()),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficesContent(List<AdminOfficeDto> offices) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('المكاتب', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              IconButton(onPressed: _refreshAll, tooltip: 'تحديث القائمة والألوان', icon: const Icon(Icons.refresh)),
              const Spacer(),
              DropdownButton<bool>(
                value: _showAllOffices,
                items: const [
                  DropdownMenuItem(value: false, child: Text('اختيار مكتب واحد')),
                  DropdownMenuItem(value: true, child: Text('جميع المستاجرين')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _showAllOffices = v;
                    _selectedOfficeId = null;
                    _sub = null;
                    _loading = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'الألوان: أزرق بعيد — أخضر — أصفر — برتقالي — أحمر قريب/منتهٍ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _showAllOffices
                ? _OfficesSubscriptionListPanel(
                    offices: offices,
                    adminApi: widget.adminApi,
                    selectedOfficeId: null,
                    refreshToken: _officeSubsRefreshToken,
                    onSelect: null,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _OfficesSubscriptionListPanel(
                          offices: offices,
                          adminApi: widget.adminApi,
                          selectedOfficeId: _selectedOfficeId,
                          refreshToken: _officeSubsRefreshToken,
                          onSelect: _loadSub,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _selectedOfficeId == null
                                ? _buildDashboardContent()
                                : (_loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : (_sub == null
                                        ? const Center(child: Text('لا توجد بيانات اشتراك'))
                                        : SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'تفاصيل الاشتراك',
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                                      ),
                                                    ),
                                                    if (_sub!.status == 'trial' || _sub!.status == 'active')
                                                      FilledButton.tonalIcon(
                                                        onPressed: () async {
                                                          final id = _selectedOfficeId;
                                                          if (id == null) return;
                                                          await _openAdminEditOfficeSubscriptionDialog(
                                                            context: context,
                                                            adminApi: widget.adminApi,
                                                            officeId: id,
                                                            officeName: () {
                                                              for (final o in offices) {
                                                                if (o.id == id) return o.name;
                                                              }
                                                              return null;
                                                            }(),
                                                            onSaved: () {
                                                              _refreshAll();
                                                              _loadSub(id);
                                                            },
                                                          );
                                                        },
                                                        icon: const Icon(Icons.edit_outlined),
                                                        label: const Text('تعديل'),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    Chip(
                                                      avatar: Icon(
                                                        _sub!.status == 'trial' ? Icons.hourglass_top : Icons.verified_outlined,
                                                        size: 18,
                                                      ),
                                                      label: Text('الحالة: ${_sub!.status}'),
                                                    ),
                                                    Chip(label: Text('المستخدمون: ${_sub!.maxUsersEffective}')),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _adminDetailRow(context, Icons.play_circle_outline, 'البداية', _sub!.startAt.toLocal().toString()),
                                                _adminDetailRow(context, Icons.flag_outlined, 'النهاية', _sub!.endAt.toLocal().toString()),
                                                if (_sub!.maxUsersOverride != null)
                                                  _adminDetailRow(context, Icons.group_outlined, 'تجاوز يدوي للحد', '${_sub!.maxUsersOverride}'),
                                                if ((_sub!.notes ?? '').isNotEmpty)
                                                  _adminDetailRow(context, Icons.notes_outlined, 'ملاحظات', _sub!.notes!),
                                              ],
                                            ),
                                          ))),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<AdminOfficeDto>>(
          future: widget.future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('تعذر تحميل المكاتب: ${snap.error}'));
            }
            final offices = snap.data ?? const <AdminOfficeDto>[];
            if (offices.isEmpty) return const Center(child: Text('لا يوجد مكاتب بعد'));
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildOfficesContent(offices),
              ),
            );
          },
        ),
      ),
    );
  }
}

bool _sameInstantUtc(DateTime a, DateTime b) =>
    (a.toUtc().millisecondsSinceEpoch - b.toUtc().millisecondsSinceEpoch).abs() < 2000;

Future<void> _openAdminEditOfficeSubscriptionDialog({
  required BuildContext context,
  required AdminApi adminApi,
  required int officeId,
  String? officeName,
  required VoidCallback onSaved,
}) async {
  AdminSubscriptionDto? sub;
  try {
    sub = await adminApi.getSubscription(officeId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل الاشتراك: $e')));
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _AdminEditSubscriptionDialog(
      adminApi: adminApi,
      officeId: officeId,
      officeName: officeName,
      initial: sub!,
      onSaved: onSaved,
    ),
  );
}

class _AdminEditSubscriptionDialog extends StatefulWidget {
  const _AdminEditSubscriptionDialog({
    required this.adminApi,
    required this.officeId,
    required this.initial,
    this.officeName,
    required this.onSaved,
  });

  final AdminApi adminApi;
  final int officeId;
  final AdminSubscriptionDto initial;
  final String? officeName;
  final VoidCallback onSaved;

  @override
  State<_AdminEditSubscriptionDialog> createState() => _AdminEditSubscriptionDialogState();
}

class _AdminEditSubscriptionDialogState extends State<_AdminEditSubscriptionDialog> {
  late DateTime _endLocal;
  late final TextEditingController _maxUsers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endLocal = widget.initial.endAt.toLocal();
    _maxUsers = TextEditingController(text: widget.initial.maxUsersOverride?.toString() ?? '');
  }

  @override
  void dispose() {
    _maxUsers.dispose();
    super.dispose();
  }

  Future<void> _pickDateOnly() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(_endLocal.year, _endLocal.month, _endLocal.day),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 8)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _endLocal = DateTime(d.year, d.month, d.day, _endLocal.hour, _endLocal.minute);
    });
  }

  Future<void> _pickTimeOnly() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endLocal));
    if (t == null || !mounted) return;
    setState(() {
      _endLocal = DateTime(_endLocal.year, _endLocal.month, _endLocal.day, t.hour, t.minute);
    });
  }

  Future<void> _pickDateAndTime() async {
    await _pickDateOnly();
    if (!mounted) return;
    await _pickTimeOnly();
  }

  Future<void> _save() async {
    final initial = widget.initial;
    final body = <String, dynamic>{};
    if (!_sameInstantUtc(_endLocal, initial.endAt)) {
      body['trial_end_at'] = _endLocal.toUtc().toIso8601String();
    }
    final t = _maxUsers.text.trim();
    final io = initial.maxUsersOverride;
    if (t.isEmpty) {
      if (io != null) body['max_users_override'] = null;
    } else {
      final v = int.tryParse(t);
      if (v == null || v < 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل عدد مستخدمين صحيح (رقم موجب)')));
        return;
      }
      if (v != io) body['max_users_override'] = v;
    }
    if (body.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.adminApi.patchOfficeSubscription(widget.officeId, body);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.officeName ?? 'مكتب #${widget.officeId}';
    final df = intl.DateFormat.yMMMd().add_Hm();
    return AlertDialog(
      title: Text('تعديل اشتراك / تجربة — $title'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الحالة: ${widget.initial.status}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('الحد الفعلي للمستخدمين الآن: ${widget.initial.maxUsersEffective}'),
            const SizedBox(height: 16),
            Text('تاريخ ووقت الانتهاء', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _saving ? null : _pickDateAndTime,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          df.format(_endLocal),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text('اضغط للتعديل', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDateOnly,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('التاريخ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickTimeOnly,
                    icon: const Icon(Icons.schedule),
                    label: const Text('الوقت'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _maxUsers,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'حد المستخدمين (اختياري)',
                hintText: 'فارغ = افتراضي الباقة أو ٣ في التجربة',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ')),
      ],
    );
  }
}

class _TrialCard extends StatelessWidget {
  const _TrialCard({required this.future, this.adminApi, this.onTrialEdited});
  final Future<AdminTrialAnalyticsDto> future;
  final AdminApi? adminApi;
  final VoidCallback? onTrialEdited;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<AdminTrialAnalyticsDto>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل التجربة: ${snap.error}');
            final data = snap.data;
            if (data == null || data.offices.isEmpty) return const Text('لا توجد مكاتب تجريبية خلال آخر 30 يوم');

            final maxUsers = data.offices.map((o) => o.activeUsersCount).fold<int>(1, (a, b) => a > b ? a : b);
            final api = adminApi;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('التجربة (آخر ${data.days} يوم)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('عدد المكاتب: ${data.totalTrialOffices}'),
                const SizedBox(height: 10),
                ...data.offices.take(6).map((o) {
                  final pct = (o.activeUsersCount / maxUsers).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(o.officeName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(value: pct, minHeight: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${o.activeUsersCount} مستخدم'),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'أيام نشاط: ${o.activeDaysCount} — ينتهي: ${o.trialEndAt.toLocal()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (api != null)
                          IconButton(
                            tooltip: 'تعديل مدة التجربة أو حد المستخدمين',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openAdminEditOfficeSubscriptionDialog(
                              context: context,
                              adminApi: api,
                              officeId: o.officeId,
                              officeName: o.officeName,
                              onSaved: onTrialEdited ?? () {},
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrialSummaryCard extends StatelessWidget {
  const _TrialSummaryCard({required this.future});
  final Future<AdminTrialAnalyticsDto> future;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<AdminTrialAnalyticsDto>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل: ${snap.error}');
            final data = snap.data;
            if (data == null) return const Text('لا توجد بيانات');

            final offices = data.offices;
            final maxUsers = offices.isEmpty ? 1 : offices.map((o) => o.activeUsersCount).fold<int>(1, (a, b) => a > b ? a : b);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.apartment_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'عدد المكاتب',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('عدد المكاتب: ${data.totalTrialOffices}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('المتوسط', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                ...offices.take(3).map((o) {
                  final pct = (o.activeUsersCount / maxUsers).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(o.officeName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE8ECF5),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF1E4DB7)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardChartCard extends StatelessWidget {
  const _DashboardChartCard({required this.days, required this.future, required this.onDaysChanged});
  final int days;
  final Future<AdminSubscriptionsSeriesDto> future;
  final ValueChanged<int> onDaysChanged;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: FutureBuilder<AdminSubscriptionsSeriesDto>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل الرسم: ${snap.error}');
            final data = snap.data;
            if (data == null || data.points.isEmpty) {
              return const SizedBox(height: 190, child: Center(child: Text('لا توجد بيانات للرسم')));
            }

            final values = data.points.map((p) => p.activeOffices.toDouble()).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المشتركين (حسب المدة)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: days,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('آخر يوم')),
                          DropdownMenuItem(value: 7, child: Text('آخر أسبوع')),
                          DropdownMenuItem(value: 30, child: Text('آخر شهر')),
                          DropdownMenuItem(value: 90, child: Text('آخر 3 شهور')),
                          DropdownMenuItem(value: 180, child: Text('آخر 6 شهور')),
                          DropdownMenuItem(value: 365, child: Text('آخر سنة')),
                        ],
                        onChanged: (v) => v == null ? null : onDaysChanged(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170,
                  child: CustomPaint(
                    painter: _MiniLineChartPainter(
                      values: values,
                      days: data.days,
                      labels: _buildXAxisLabels(context, data),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _buildXAxisLabels(BuildContext context, AdminSubscriptionsSeriesDto data) {
    final pts = data.points;
    if (pts.isEmpty) return const [];
    final n = pts.length;
    final isLong = data.days > 31;
    final monthsAr = const ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];
    final labels = <String>[];
    for (var i = 0; i < n; i++) {
      final d = pts[i].day;
      if (isLong) {
        labels.add(monthsAr[d.month - 1]);
      } else {
        labels.add('${d.day}');
      }
    }
    return labels;
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({required this.values, required this.days, required this.labels});
  final List<double> values;
  final int days;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF7F9FF);
    final grid = Paint()
      ..color = const Color(0xFFE6EBF7)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = const Color(0xFF1E4DB7)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0xFF1E4DB7).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    // chart paddings for axes/labels
    const leftPad = 8.0;
    const rightPad = 40.0;
    const topPad = 10.0;
    const bottomPad = 22.0;

    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, bg);

    // grid lines
    for (var i = 1; i <= 3; i++) {
      final y = topPad + (size.height - topPad - bottomPad) * (i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), grid);
    }

    if (values.isEmpty) return;
    final maxV = values.fold<double>(1, (a, b) => a > b ? a : b).clamp(1, double.infinity);
    final minV = values.fold<double>(values.first, (a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final n = values.length;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;
    final dx = n <= 1 ? 0.0 : w / (n - 1);
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final norm = (values[i] - minV) / span;
      final x = leftPad + dx * i;
      final y = topPad + (h - (norm * h));
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, topPad + h)
      ..lineTo(pts.first.dx, topPad + h)
      ..close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);

    final dot = Paint()..color = const Color(0xFF1E4DB7);
    for (final p in pts) {
      canvas.drawCircle(p, 3.2, dot);
    }

    // right axis % labels
    final tpAxis = TextPainter(textDirection: TextDirection.rtl);
    for (final pct in const [0, 25, 50, 75, 100]) {
      final y = topPad + (h - (pct / 100) * h);
      tpAxis.text = TextSpan(text: '$pct%', style: const TextStyle(color: Color(0xFF7482A6), fontSize: 10));
      tpAxis.layout();
      tpAxis.paint(canvas, Offset(size.width - rightPad + 6, y - tpAxis.height / 2));
    }

    // bottom x labels (sample)
    final tpX = TextPainter(textDirection: TextDirection.rtl, maxLines: 1, ellipsis: '…');
    final steps = n <= 6 ? 1 : (n / 6).ceil();
    for (var i = 0; i < n; i += steps) {
      if (i >= labels.length) break;
      tpX.text = TextSpan(text: labels[i], style: const TextStyle(color: Color(0xFF7482A6), fontSize: 10));
      tpX.layout(maxWidth: 36);
      tpX.paint(canvas, Offset(pts[i].dx - (tpX.width / 2), topPad + h + 4));
    }

    // point labels: count
    final tpVal = TextPainter(textDirection: TextDirection.rtl, maxLines: 1);
    for (var i = 0; i < pts.length; i++) {
      final txt = values[i].toInt().toString();
      tpVal.text = TextSpan(text: txt, style: const TextStyle(color: Color(0xFF0F2A5F), fontSize: 10, fontWeight: FontWeight.w800));
      tpVal.layout();
      tpVal.paint(canvas, Offset(pts[i].dx - tpVal.width / 2, pts[i].dy - tpVal.height - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.days != days || oldDelegate.labels != labels;
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _ActiveSubsCard extends StatelessWidget {
  const _ActiveSubsCard({required this.future});
  final Future<AdminSubscriptionsAnalyticsDto> future;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<AdminSubscriptionsAnalyticsDto>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل الاشتراكات: ${snap.error}');
            final data = snap.data;
            if (data == null) return const Text('لا توجد بيانات');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الاشتراكات الفعلية', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('إجمالي المكاتب المشتركة: ${data.totalActiveOffices}'),
                const SizedBox(height: 10),
                ...data.byPlan.take(6).map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.planName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('${p.officeCount}'),
                        const SizedBox(width: 8),
                        Text('متوسط متبقي: ${p.avgRemainingDays} يوم', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.future});
  final Future<AdminAlertsDto> future;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<AdminAlertsDto>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل التحذيرات: ${snap.error}');
            final a = snap.data;
            if (a == null) return const Text('لا توجد بيانات');

            Widget pill({required Color c, required String title, required int value}) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                      child: Text('$value', style: TextStyle(color: c, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('تحذيرات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                pill(c: const Color(0xFFF59E0B), title: 'تجارب تنتهي خلال 3 أيام', value: a.trialExpiring3d),
                pill(c: const Color(0xFF3B82F6), title: 'اشتراكات تنتهي خلال 7 أيام', value: a.activeExpiring7d),
                pill(c: const Color(0xFFEF4444), title: 'منتهية/غير فعّالة', value: a.expiredOrInactive),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SuperAdminsCard extends StatelessWidget {
  const _SuperAdminsCard({required this.future, required this.adminApi, required this.onRefresh});
  final Future<List<AdminSuperAdminDto>> future;
  final AdminApi adminApi;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<AdminSuperAdminDto>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (snap.hasError) return Text('تعذر تحميل مستخدمي السوبر أدمن: ${snap.error}');
            final items = snap.data ?? const <AdminSuperAdminDto>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('المستخدمين والصلاحيات', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(onPressed: onRefresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
                    FilledButton.tonal(
                      onPressed: () async {
                        final name = TextEditingController();
                        final email = TextEditingController();
                        final pass = TextEditingController();
                        try {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('إضافة سوبر أدمن'),
                              content: SizedBox(
                                width: 520,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
                                    const SizedBox(height: 10),
                                    TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد')),
                                    const SizedBox(height: 10),
                                    TextField(controller: pass, decoration: const InputDecoration(labelText: 'كلمة المرور'), obscureText: true),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await adminApi.createSuperAdmin(fullName: name.text.trim(), email: email.text.trim(), password: pass.text);
                          onRefresh();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الإضافة: $e')));
                          }
                        } finally {
                          name.dispose();
                          email.dispose();
                          pass.dispose();
                        }
                      },
                      child: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty) const Text('لا يوجد مستخدمين') else ...items.take(5).map((u) {
                  return Row(
                    children: [
                      Expanded(child: Text(u.fullName ?? u.email, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(u.isActive ? 'نشط' : 'مُعطّل', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 6),
                      if (u.isActive)
                        IconButton(
                          tooltip: 'تعطيل',
                          onPressed: () async {
                            try {
                              await adminApi.disableSuperAdmin(u.id);
                              onRefresh();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التعطيل: $e')));
                              }
                            }
                          },
                          icon: const Icon(Icons.block),
                        ),
                    ],
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.meFuture,
    required this.currentPass,
    required this.newEmail,
    required this.newPass,
    required this.saving,
    required this.onSave,
  });

  final Future<MeDto> meFuture;
  final TextEditingController currentPass;
  final TextEditingController newEmail;
  final TextEditingController newPass;
  final bool saving;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<MeDto>(
          future: meFuture,
          builder: (context, snap) {
            final email = snap.data?.email ?? '—';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الحساب الحالي: $email'),
                const SizedBox(height: 16),
                Text('تغيير البريد/كلمة المرور', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: currentPass,
                  labelText: 'كلمة المرور الحالية',
                  enabled: !saving,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newEmail,
                  decoration: const InputDecoration(labelText: 'البريد الجديد (اختياري)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: newPass,
                  labelText: 'كلمة المرور الجديدة (اختياري)',
                  enabled: !saving,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('حفظ التغييرات'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
