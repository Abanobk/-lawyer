import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';
import 'package:lawyer_app/data/api/sessions_api.dart';

class OfficeSearchLaunchButton extends StatelessWidget {
  const OfficeSearchLaunchButton({super.key, required this.officeCode});

  final String officeCode;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'بحث في المكتب',
      icon: const Icon(Icons.search),
      onPressed: () {
        showSearch<void>(
          context: context,
          delegate: OfficeSearchDelegate(officeCode: officeCode),
        );
      },
    );
  }
}

class OfficeSearchDelegate extends SearchDelegate<void> {
  OfficeSearchDelegate({required this.officeCode});

  final String officeCode;

  Future<_SearchBundle>? _future;

  Future<_SearchBundle> _ensureLoaded() {
    _future ??= Future.wait([
      CasesApi().list(),
      ClientsApi().list(),
      SessionsApi().list(),
    ]).then((r) => _SearchBundle(
          cases: r[0] as List<CaseDto>,
          clients: r[1] as List<ClientDto>,
          sessions: r[2] as List<SessionDto>,
        ));
    return _future!;
  }

  @override
  String get searchFieldLabel => 'بحث في القضايا والموكلين والجلسات…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        tooltip: 'مسح',
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  String _caseNum(CaseDto c) {
    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) {
      if (c.caseYear != null) return '${c.caseNumber}/${c.caseYear}';
      return c.caseNumber!;
    }
    return '#${c.id}';
  }

  Widget _buildList(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return FutureBuilder<_SearchBundle>(
      future: _ensureLoaded(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final b = snap.data!;
        final q = query.trim().toLowerCase();
        if (q.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'اكتب اسم الموكل، عنوان القضية، رقم الملف، أو جزء من تاريخ الجلسة.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        }

        final tiles = <Widget>[];

        for (final c in b.cases) {
          final hay = '${c.title} ${c.clientName} ${c.caseNumber ?? ''} ${c.court ?? ''} ${c.id}'.toLowerCase();
          if (hay.contains(q)) {
            tiles.add(
              ListTile(
                leading: const Icon(Icons.work_outline),
                title: Text(c.title),
                subtitle: Text('${c.clientName} · ${_caseNum(c)}'),
                onTap: () {
                  close(context, null);
                  context.go('/o/$officeCode/cases/${c.id}');
                },
              ),
            );
          }
        }

        for (final cl in b.clients) {
          final hay = '${cl.fullName} ${cl.phone ?? ''} ${cl.nationalId ?? ''} ${cl.id}'.toLowerCase();
          if (hay.contains(q)) {
            tiles.add(
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(cl.fullName),
                subtitle: Text(cl.phone ?? 'موكل #${cl.id}'),
                onTap: () {
                  close(context, null);
                  context.go('/o/$officeCode/clients');
                },
              ),
            );
          }
        }

        for (final s in b.sessions) {
          final hay =
              '${s.caseTitle} ${s.clientName} ${s.sessionNumber ?? ''} ${df.format(s.sessionDate.toLocal())}'.toLowerCase();
          if (hay.contains(q)) {
            tiles.add(
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(s.caseTitle),
                subtitle: Text('${df.format(s.sessionDate.toLocal())} · ${s.clientName}'),
                onTap: () {
                  close(context, null);
                  context.go('/o/$officeCode/cases/${s.caseId}');
                },
              ),
            );
          }
        }

        if (tiles.isEmpty) {
          return Center(
            child: Text(
              'لا نتائج لـ «$query»',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView(children: tiles);
      },
    );
  }
}

class _SearchBundle {
  _SearchBundle({
    required this.cases,
    required this.clients,
    required this.sessions,
  });

  final List<CaseDto> cases;
  final List<ClientDto> clients;
  final List<SessionDto> sessions;
}
