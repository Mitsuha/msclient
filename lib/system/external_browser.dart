import 'package:url_launcher/url_launcher.dart';

/// Opens URLs in the system default browser.
class ExternalBrowser {
  const ExternalBrowser();

  Future<void> open(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open $url');
    }
  }
}
