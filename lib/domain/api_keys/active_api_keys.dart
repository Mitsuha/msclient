/// API keys currently used by local tool configs.
/// This in-memory state is re-read from disk and never persisted.
class ActiveApiKeys {
  const ActiveApiKeys({this.codexKey = '', this.claudeKey = ''});

  /// Nothing read yet, or neither tool is in API-key mode.
  static const ActiveApiKeys none = ActiveApiKeys();

  /// `OPENAI_API_KEY` from `~/.codex/auth.json`; empty when Codex is not on a
  /// key (an OAuth account, or no config at all).
  final String codexKey;

  /// `env.ANTHROPIC_AUTH_TOKEN` from `~/.claude/settings.json`; empty when
  /// Claude Code is not on a key.
  final String claudeKey;

  /// Whether [key] is the one at least one tool is currently running on — what
  /// turns a row's 启用 button into 正在使用.
  bool isInUse(String key) =>
      key.isNotEmpty && (key == codexKey || key == claudeKey);

  @override
  bool operator ==(Object other) =>
      other is ActiveApiKeys &&
      other.codexKey == codexKey &&
      other.claudeKey == claudeKey;

  @override
  int get hashCode => Object.hash(codexKey, claudeKey);
}
