import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytesAsFileOnWeb({
  required Uint8List bytes,
  required String contentType,
  required String filename,
}) {
  final bytesPart = bytes.toJS as web.BlobPart;
  final parts = <web.BlobPart>[bytesPart].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: contentType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

void openBytesInNewTabOnWeb({
  required Uint8List bytes,
  required String contentType,
}) {
  final bytesPart = bytes.toJS as web.BlobPart;
  final parts = <web.BlobPart>[bytesPart].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: contentType));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener';
  a.click();
  Future<void>.delayed(const Duration(seconds: 2), () {
    web.URL.revokeObjectURL(url);
  });
}
