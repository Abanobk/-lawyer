import 'package:lawyer_app/data/api/cases_api.dart';
import 'package:lawyer_app/data/api/clients_api.dart';

String _csvField(String? s) {
  final v = s ?? '';
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// تصدير الموكلين لملف CSV (UTF-8، مناسب لبرنامج Excel مع BOM في التنزيل).
String clientsToCsv(List<ClientDto> clients) {
  final sb = StringBuffer();
  sb.writeln('id,full_name,phone,national_id,address,notes,created_at');
  for (final c in clients) {
    sb.writeln([
      c.id,
      _csvField(c.fullName),
      _csvField(c.phone),
      _csvField(c.nationalId),
      _csvField(c.address),
      _csvField(c.notes),
      _csvField(c.createdAt.toIso8601String()),
    ].join(','));
  }
  return sb.toString();
}

/// تصدير القضايا لملف CSV.
String casesToCsv(List<CaseDto> cases) {
  final sb = StringBuffer();
  sb.writeln(
    'id,client_id,client_name,title,kind,court,case_number,case_year,first_hearing_at,fee_total,is_active,primary_lawyer_email,created_at',
  );
  for (final c in cases) {
    sb.writeln([
      c.id,
      c.clientId,
      _csvField(c.clientName),
      _csvField(c.title),
      _csvField(c.kind),
      _csvField(c.court),
      _csvField(c.caseNumber),
      c.caseYear ?? '',
      c.firstHearingAt?.toIso8601String() ?? '',
      c.feeTotal ?? '',
      c.isActive,
      _csvField(c.primaryLawyerEmail),
      _csvField(c.createdAt.toIso8601String()),
    ].join(','));
  }
  return sb.toString();
}
