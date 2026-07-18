import 'package:desktop/data/api/tool_auth_api.dart';
import 'package:desktop/domain/tools/codex_initializer.dart';
import 'package:desktop/domain/tools/tool.dart';
import 'package:desktop/domain/tools/tool_initializer.dart';
import 'package:desktop/system/codex_config_manager.dart';

/// The Codex tool: `~/.codex` config (auth.json / .env / config.toml) plus the
/// `/user/codex-auth` credential endpoint. All orchestration lives in
/// [ConfiguredTool]; this only wires the Codex-specific initializer.
class CodexTool extends ConfiguredTool<CodexConfigManager> {
  CodexTool({
    required super.config,
    required this._authApi,
    required this._resolveProxyUrl,
    required this._requireToken,
  });

  final ToolAuthApi _authApi;
  final ResolveProxyUrl _resolveProxyUrl;
  final RequireToken _requireToken;

  @override
  ToolId get id => ToolId.codex;

  @override
  ToolInitializer initializer({int userPackId = 0}) => codexInitializer(
    config: config,
    resolveProxyUrl: _resolveProxyUrl,
    fetchAuth: () async => _authApi.createAuth(
      token: await _requireToken(),
      userPackId: userPackId,
    ),
  );
}
