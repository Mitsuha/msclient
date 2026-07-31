/// Environment constants for the production deployment.
abstract final class AppConfig {
  static final Uri apiBaseUri = Uri.parse(
    'https://platform.mirrorstages.com/api',
  );

  /// Fallback remote node when the server list is unavailable.
  static const String proxyUrl = 'https://api.mirrorstages.com:5211';

  static const String adminConsoleUrl = 'https://dashboard.mirrorstages.com';
  static const String registerUrl =
      'https://dashboard.mirrorstages.com/auth/register?utm_type=app';

  /// Where keys are actually created and revoked; the app only lists them.
  static const String apiKeysConsoleUrl =
      'https://dashboard.mirrorstages.com/api-keys';
  static const String rootCertificateAssetPath =
      'assets/ca/mirrorstages-root-ca.cer';

  // ── API key mode ───────────────────────────────────────────────────────────

  /// Anthropic-compatible endpoint Claude Code is pointed at when a key is
  /// activated (`ANTHROPIC_BASE_URL`).
  static const String anthropicBaseUrl =
      'https://api.mirrorstages.com/anthropic';

  /// OpenAI-compatible endpoint Codex is pointed at when a key is activated.
  static const String openaiBaseUrl = 'https://api.mirrorstages.com/openai';

  /// Key of the `[model_providers.*]` table written into Codex's `config.toml`;
  /// `model_provider` must name it for Codex to resolve the provider.
  static const String codexProviderKey = 'Mirrorstages';

  // ── sing-box ───────────────────────────────────────────────────────────────

  /// `~/.mstages`: holds the sing-box binary, config file, and runtime log.
  static const String dataDirectoryName = '.mstages';

  /// Where a missing sing-box binary is fetched from; `sing-box-<os>[.exe]` is
  /// appended per platform.
  static const String singboxDownloadBaseUrl =
      'https://cnb.cool/mirrorstages/gost/-/git/raw/main';

  /// Loopback host for the local proxy and the Clash API.
  static const String singboxHost = '127.0.0.1';

  /// Local HTTP proxy port the CLI tools route through.
  static const int singboxProxyPort = 18610;

  /// Clash API port used to switch the selector at runtime.
  static const int singboxApiPort = 18611;

  /// Bearer secret guarding the loopback Clash API.
  static const String singboxClashSecret = 'default-secret';

  /// Generated config file name under [dataDirectoryName].
  static const String singboxConfigFileName = 'sing-box.json';

  /// Constant local proxy address written into every tool's config.
  static const String singboxLocalProxyUrl =
      'http://$singboxHost:$singboxProxyPort';

  /// Base URI of the Clash API.
  static Uri get singboxClashApiBaseUri =>
      Uri.parse('http://$singboxHost:$singboxApiPort');
}
