import 'package:lawyer_app/data/api/me_api.dart';
import 'package:lawyer_app/data/api/office_api.dart';

typedef OfficeInfo = ({int id, String code, String name});

/// يحمّل المستخدم الحالي وبيانات المكتب لعرض الترحيب (شريط علوي + بانر).
Future<(MeDto, OfficeInfo)> loadOfficeWelcomeContext() async {
  final me = await MeApi().me();
  final o = await OfficeApi().myOffice();
  return (me, o);
}

String officeUserDisplayName(MeDto me) {
  final n = me.fullName?.trim();
  if (n != null && n.isNotEmpty) return n;
  final p = me.email.split('@').first;
  return p.isEmpty ? 'محامٍ' : p;
}

String officeUserInitial(MeDto me) {
  final d = officeUserDisplayName(me);
  if (d.isEmpty) return '؟';
  return d.substring(0, 1);
}
