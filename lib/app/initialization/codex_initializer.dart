import 'package:desktop/app/initialization/tool_initializer.dart';
import 'package:desktop/system/codex_config_manager.dart';

/// Step ids of the Codex initialization, in order.
abstract final class CodexInitSteps {
  static const proxyEnv = 'codex.proxy_env';
  static const auth = 'codex.auth';
  static const providerConfig = 'codex.provider_config';
}

/// Builds the ordered Codex initialization steps against [config].
///
/// [resolveProxyUrl] supplies the proxy node currently selected in settings;
/// [fetchAuth] requests fresh MirrorStages credentials from the server (the
/// billing pack is baked into the closure by the caller). The user's original
/// files are backed up into `~/.codex/old_config` only during a full
/// first-time initialization, not when a single step is applied.
ToolInitializer codexInitializer({
  required CodexConfigManager config,
  required Future<String> Function() resolveProxyUrl,
  required Future<Map<String, dynamic>> Function() fetchAuth,
}) {
  return ToolInitializer([
    InitStep(
      id: CodexInitSteps.proxyEnv,
      title: '代理配置',
      description: '通过 Mirrorstages 来确保一致的网络环境。',
      check: config.hasProxyEnv,
      apply: () async => config.writeProxyEnv(await resolveProxyUrl()),
    ),
    InitStep(
      id: CodexInitSteps.auth,
      title: '授权凭据',
      description: '写入 Codex 账号授权凭据。',
      check: config.hasMirrorStagesAuth,
      apply: () async => config.writeAuth(await fetchAuth()),
    ),
    InitStep(
      id: CodexInitSteps.providerConfig,
      title: 'Provider 配置',
      description: '删除之前配置的第三方 API，使用 Codex 账户直接访问',
      check: config.hasCleanProviderConfig,
      apply: config.clearProviderConfig,
    ),
  ], preserveOriginals: config.preserveOriginals);
}
