import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lawyer_app/features/admin/admin_gate_page.dart';
import 'package:lawyer_app/features/auth/login_page.dart';
import 'package:lawyer_app/features/auth/signup_page.dart';
import 'package:lawyer_app/features/landing/landing_page.dart';
import 'package:lawyer_app/features/office/office_shell.dart';
import 'package:lawyer_app/features/office/pages/accounts_page.dart';
import 'package:lawyer_app/features/office/pages/case_detail_page.dart';
import 'package:lawyer_app/features/office/pages/cases_page.dart';
import 'package:lawyer_app/features/office/pages/clients_page.dart';
import 'package:lawyer_app/features/office/pages/custody_page.dart';
import 'package:lawyer_app/features/office/pages/dashboard_page.dart';
import 'package:lawyer_app/features/office/pages/employees_page.dart';
import 'package:lawyer_app/features/office/pages/sessions_page.dart';
import 'package:lawyer_app/features/office/pages/settings_page.dart';
import 'package:lawyer_app/features/office/pages/subscription_page.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminGatePage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final code = state.pathParameters['officeCode']!;
          return OfficeShell(officeCode: code, child: child);
        },
        routes: [
          GoRoute(
            path: '/o/:officeCode',
            redirect: (context, state) {
              final segs = state.uri.pathSegments;
              if (segs.length <= 2) {
                return '/o/${state.pathParameters['officeCode']}/dashboard';
              }
              return null;
            },
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
              GoRoute(
                path: 'clients',
                builder: (context, state) => const ClientsPage(),
              ),
              GoRoute(
                path: 'cases',
                builder: (context, state) => const CasesPage(),
                routes: [
                  GoRoute(
                    path: ':caseId',
                    builder: (context, state) {
                      final raw = state.pathParameters['caseId'] ?? '';
                      final id = int.tryParse(raw) ?? 0;
                      return CaseDetailPage(caseId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'sessions',
                builder: (context, state) => const SessionsPage(),
              ),
              GoRoute(
                path: 'accounts',
                builder: (context, state) => const AccountsPage(),
              ),
              GoRoute(
                path: 'custody',
                redirect: (context, state) {
                  final code = state.pathParameters['officeCode']!;
                  return '/o/$code/accounts?tab=custody';
                },
                builder: (context, state) => const CustodyPage(),
              ),
              GoRoute(
                path: 'employees',
                builder: (context, state) => const EmployeesPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
              GoRoute(
                path: 'subscription',
                builder: (context, state) => const SubscriptionPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
