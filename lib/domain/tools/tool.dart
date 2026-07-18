import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/domain/tools/tool_initializer.dart';
import 'package:desktop/system/tool_config_manager.dart';

/// Identifies a supported local AI CLI tool.
enum ToolId { codex, claude }

/// Fetches fresh MirrorStages credentials, billed against the pack baked into
/// the closure by the caller.
typedef FetchToolAuth = Future<Map<String, dynamic>> Function();

/// Supplies the local proxy url the tool's config should point at.
typedef ResolveProxyUrl = Future<String> Function();

/// Supplies the current session token, throwing when signed out.
typedef RequireToken = Future<String> Function();

/// Where a tool's config lives on this machine and whether it can be rolled
/// back — the local, non-account half of a tool's state.
class ToolInstallInfo {
  const ToolInstallInfo({
    required this.directoryPath,
    required this.isInstalled,
    required this.canRestoreConfig,
  });

  final String directoryPath;
  final bool isInstalled;

  /// Whether a backup of the user's pre-MirrorStages config exists to restore.
  final bool canRestoreConfig;
}

/// A local AI CLI tool MirrorStages initializes and bills (Codex, Claude Code).
///
/// One instance per supported tool. It bundles everything that used to be split
/// across per-tool config managers, initializers, and duplicated AppService
/// method pairs, so the orchestration layer can loop over `List<Tool>` instead
/// of branching codex-vs-claude by hand. Adding a tool is a new [Tool]
/// implementation plus a registry entry — no edits scattered across layers.
abstract interface class Tool {
  ToolId get id;

  /// The account the tool is authorized as, or uninitialized.
  Future<ToolStatus> readStatus();

  /// Where the tool lives and whether its config can be restored.
  Future<ToolInstallInfo> readInstallInfo();

  /// Per-step check results of the tool's initialization, in order, so the
  /// settings page can verify and repair steps individually.
  Future<List<InitStepStatus>> checkSteps();

  /// Runs the full initialization billed against [userPackId] (0 =
  /// pay-as-you-go / 按量计费). Backs up the user's originals only on a genuine
  /// first-time initialization.
  Future<void> initialize({int userPackId = 0});

  /// Re-applies a single initialization step, keeping the billing pack the
  /// current credentials are on.
  Future<void> applyStep(String stepId);

  /// Restores the user's pre-MirrorStages config. Throws when none was backed
  /// up.
  Future<void> restoreOriginals();

  /// Whether the on-disk credentials are still a MirrorStages-issued account,
  /// even with the proxy config currently absent (launch-time re-apply).
  Future<bool> hasIssuedCredentials();

  /// Points the tool at [proxyUrl].
  Future<void> writeProxy(String proxyUrl);

  /// Surgically removes the proxy entries on quit, keeping every other setting.
  Future<void> stripProxy();

  /// Fully clears the MirrorStages proxy config (settings-page action).
  Future<void> clearProxy();
}

/// A [Tool] backed by a [ToolConfigManager] and a [ToolInitializer]. Holds the
/// orchestration every tool shares; a subclass supplies only [id] and the
/// [initializer] factory (which differs per tool), and is typed on its concrete
/// config manager [C] so that factory can reach tool-specific methods.
abstract class ConfiguredTool<C extends ToolConfigManager> implements Tool {
  ConfiguredTool({required this.config});

  final C config;

  /// Builds the ordered init steps billed against [userPackId]; the pack only
  /// matters when a step is actually applied.
  ToolInitializer initializer({int userPackId = 0});

  @override
  Future<ToolStatus> readStatus() => config.readStatus();

  @override
  Future<ToolInstallInfo> readInstallInfo() async => ToolInstallInfo(
    directoryPath: await config.directoryPath(),
    isInstalled: await config.isInstalled(),
    canRestoreConfig: await config.hasRestorableBackup(),
  );

  @override
  Future<List<InitStepStatus>> checkSteps() => initializer().checkSteps();

  @override
  Future<void> initialize({int userPackId = 0}) async {
    // Back up the user's pristine files only on a genuine first-time init, so
    // the backup never captures a MirrorStages-written config.
    final firstTime = !(await config.readStatus()).isInitialized;
    await initializer(
      userPackId: userPackId,
    ).initialize(backupOriginals: firstTime);
  }

  @override
  Future<void> applyStep(String stepId) async {
    final userPackId = (await config.readStatus()).account?.userPackId ?? 0;
    await initializer(userPackId: userPackId).applyStep(stepId);
  }

  @override
  Future<void> restoreOriginals() => config.restoreOriginals();

  @override
  Future<bool> hasIssuedCredentials() => config.hasIssuedCredentials();

  @override
  Future<void> writeProxy(String proxyUrl) => config.writeProxy(proxyUrl);

  @override
  Future<void> stripProxy() => config.stripProxy();

  @override
  Future<void> clearProxy() => config.clearProxy();
}
