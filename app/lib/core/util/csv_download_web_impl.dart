import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// تنزيل نص CSV على الويب مع BOM لدعم العربية في Excel.
void downloadCsvWeb(String filename, String csvBody) {
  if (!kIsWeb) return;
  final text = '\uFEFF$csvBody';
  final u8 = Uint8List.fromList(utf8.encode(text));
  final parts = <web.BlobPart>[u8.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}
