class LocalConfigurationStatus {
  const LocalConfigurationStatus({
    required this.codexDirectoryPath,
    required this.claudeDirectoryPath,
    required this.isCodexInstalled,
    required this.isClaudeInstalled,
    required this.canRestoreCodexConfig,
    required this.canRestoreClaudeConfig,
    required this.rootCertificate,
  });

  final String codexDirectoryPath;
  final String claudeDirectoryPath;
  final bool isCodexInstalled;
  final bool isClaudeInstalled;

  /// Whether a `~/.codex/old_config` backup exists that can be restored.
  final bool canRestoreCodexConfig;

  /// Whether a `~/.claude/old_config` backup exists that can be restored.
  final bool canRestoreClaudeConfig;
  final RootCertificateStatus rootCertificate;
}

class RootCertificateStatus {
  const RootCertificateStatus({
    required this.assetPath,
    required this.isInstalled,
  });

  final String assetPath;
  final bool isInstalled;
}
