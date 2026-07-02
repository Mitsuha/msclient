/// Environment constants for the production deployment.
abstract final class AppConfig {
  static final Uri apiBaseUri = Uri.parse(
    'https://platform.mirrorstages.com/api',
  );
  static const String proxyUrl = 'https://api.mirrorstages.com:5211';
  static const String adminConsoleUrl = 'https://dashboard.mirrorstages.com';
  static const String rootCertificateAssetPath =
      'assets/ca/mirrorstages-root-ca.cer';
}
