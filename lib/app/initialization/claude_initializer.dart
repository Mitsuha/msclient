import 'package:desktop/app/initialization/tool_initializer.dart';
import 'package:desktop/system/claude_config_manager.dart';

/// Step ids of the Claude Code initialization, in order.
abstract final class ClaudeInitSteps {
  static const credentials = 'claude.credentials';
  static const proxySettings = 'claude.proxy_settings';
}

/// Builds the ordered Claude Code initialization steps against [config].
///
/// [resolveProxyUrl] supplies the proxy node currently selected in settings;
/// [fetchAuth] requests fresh MirrorStages credentials from the server (the
/// billing pack is baked into the closure by the caller). The user's original
/// config is backed up into `~/.claude/old_config` only during a full
/// first-time initialization, not when a single step is applied.
ToolInitializer claudeInitializer({
  required ClaudeConfigManager config,
  required Future<String> Function() resolveProxyUrl,
  required Future<Map<String, dynamic>> Function() fetchAuth,
}) {
  return ToolInitializer([
    InitStep(
      id: ClaudeInitSteps.credentials,
      title: '授权凭据',
      description: '写入 MirrorStages 授权凭据（macOS 为钥匙串）并更新 ~/.claude.json 账户信息。',
      check: config.hasMirrorStagesCredentials,
      apply: () async => config.writeAuth(await fetchAuth()),
    ),
    InitStep(
      id: ClaudeInitSteps.proxySettings,
      title: '代理设置',
      description: 'settings.json 中写入 HTTPS_PROXY / HTTP_PROXY 代理地址。',
      check: config.hasProxySettings,
      apply: () async => config.writeProxySettings(await resolveProxyUrl()),
    ),
  ], preserveOriginals: config.preserveOriginals);
}
