import 'dart:typed_data';

import 'web_file_download_stub.dart'
    if (dart.library.html) 'web_file_download_web.dart' as impl;

/// Trigger a browser download for bytes (web only). No-op on mobile/desktop.
void downloadBytesAsFileOnWeb({
  required Uint8List bytes,
  required String contentType,
  required String filename,
}) {
  impl.downloadBytesAsFileOnWeb(
    bytes: bytes,
    contentType: contentType,
    filename: filename,
  );
}

/// Open bytes in a new browser tab (web only). No-op on mobile/desktop.
void openBytesInNewTabOnWeb({
  required Uint8List bytes,
  required String contentType,
}) {
  impl.openBytesInNewTabOnWeb(bytes: bytes, contentType: contentType);
}
