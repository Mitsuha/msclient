import 'dart:io';

/// Opens URLs in the system default browser.
class ExternalBrowser {
  const ExternalBrowser();

  Future<void> open(String url) async {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
      return;
    }
    await Process.run('xdg-open', [url]);
  }
}
