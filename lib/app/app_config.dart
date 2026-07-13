/// Environment constants for the production deployment.
abstract final class AppConfig {
  static final Uri apiBaseUri = Uri.parse(
    'https://platform.mirrorstages.com/api',
  );

  /// The upstream MirrorStages proxy node used as the fallback when the server
  /// list of nodes is unavailable. This is the *remote* address that local
  /// gost forwards to — the CLI tools themselves point at [gostLocalProxyUrl].
  static const String proxyUrl = 'https://api.mirrorstages.com:5211';

  static const String adminConsoleUrl = 'https://dashboard.mirrorstages.com';
  static const String rootCertificateAssetPath =
      'assets/ca/mirrorstages-root-ca.cer';

  // ── go-gost ──────────────────────────────────────────────────────────────
  //
  // A go-gost binary is downloaded on first launch and run for the lifetime of
  // the app. It exposes a local HTTP proxy that the CLI tools point at, and
  // forwards through a chain to the selected remote node. The chain is
  // (re)configured over gost's REST API — see GostController / GostApiClient.

  /// The `~/.mstages` subdirectory (under the user's home) that holds the gost
  /// binary, runtime log, and any other MirrorStages-managed local state.
  static const String dataDirectoryName = '.mstages';

  /// Base URL the platform-specific gost binary is fetched from on first run.
  /// The asset name (`gost_<os>_<arch>[.exe]`) is appended per platform.
  static const String gostDownloadBaseUrl =
      'https://cnb.cool/mirrorstages/gost/-/git/raw/main';

  /// Loopback host both the local proxy and the control API bind to.
  static const String gostHost = '127.0.0.1';

  /// Port of the local HTTP proxy the CLI tools route through.
  static const int gostProxyPort = 18610;

  /// Port of gost's REST control API used to (re)configure the chain.
  static const int gostApiPort = 18611;

  /// The local proxy address written into every tool's config; constant across
  /// node switches (only gost's forwarding chain changes).
  static const String gostLocalProxyUrl = 'http://$gostHost:$gostProxyPort';

  /// Base URI of gost's control API (`/config`, `/config/chains`, …).
  static Uri get gostApiBaseUri => Uri.parse('http://$gostHost:$gostApiPort');
}
