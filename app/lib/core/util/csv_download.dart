import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web_impl.dart' as impl;

/// Web-only CSV download (UTF‑8 + BOM). No-op on mobile/desktop.
void downloadCsvWeb(String filename, String csvBody) {
  impl.downloadCsvWeb(filename, csvBody);
}
