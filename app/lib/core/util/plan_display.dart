import 'package:lawyer_app/data/api/plans_api.dart';

String planGroupKey(PlanDto p) {
  final pk = p.packageKey?.trim() ?? '';
  if (pk.isNotEmpty) return 'k:$pk';
  final pn = p.packageName?.trim() ?? '';
  if (pn.isNotEmpty) return 'n:$pn';
  return 'u:${p.id}';
}

/// تجميع الخطط النشطة حسب [package_key] ثم [package_name]؛ كل مجموعة = بطاقة واحدة في الواجهة.
List<List<PlanDto>> groupPlansByPackage(List<PlanDto> plans, {int maxGroups = 6}) {
  final active = plans.where((p) => p.isActive).toList();
  final map = <String, List<PlanDto>>{};
  for (final p in active) {
    map.putIfAbsent(planGroupKey(p), () => []).add(p);
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

/// أول خطة في المجموعة لها صورة دعائية؛ وإلا الأولى.
PlanDto planForPromoImage(List<PlanDto> group) {
  for (final p in group) {
    final path = p.promoImagePath?.trim() ?? '';
    if (path.isNotEmpty) return p;
  }
  return group.first;
}
