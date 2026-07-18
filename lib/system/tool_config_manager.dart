import 'package:desktop/app/models/tool_status.dart';

/// The shared contract for a local AI CLI tool's on-disk configuration.
///
/// Each tool (Codex, Claude Code) owns all of its own detection and mutation
/// behind this interface, so the orchestration layer can treat both tools
/// uniformly — see `Tool` / `ConfiguredTool` in `domain/tools`.
///
/// The interface is split in two: the read side (where it lives, whether it is
/// installed, its status) and the proxy/backup lifecycle the app drives around
/// launch, quit, and the settings page. The per-step check/write pairs used by
/// the initializers are *not* here — those stay on the concrete managers, since
/// the steps differ per tool by design.
abstract interface class ToolConfigManager {
  /// The tool's configuration directory (e.g. `~/.codex`, `~/.claude`).
  Future<String> directoryPath();

  /// Whether the tool's configuration directory exists on this machine.
  Future<bool> isInstalled();

  /// Reads the stored credentials and reports the initialization state. Any
  /// failure is treated as [ToolStatus.uninitialized] rather than surfaced.
  Future<ToolStatus> readStatus();

  /// Whether the on-disk credentials are a MirrorStages-issued account, judged
  /// from the credentials alone — so it still recognizes our account when the
  /// proxy config is currently absent (unlike [readStatus], which also requires
  /// the proxy). Used by the launch-time proxy re-apply.
  Future<bool> hasIssuedCredentials();

  /// Whether a restorable backup of the user's pre-MirrorStages config exists.
  Future<bool> hasRestorableBackup();

  /// Points the tool's config at the local proxy [proxyUrl], preserving every
  /// other setting.
  Future<void> writeProxy(String proxyUrl);

  /// Surgically removes only the proxy entries (used on quit), preserving every
  /// other setting so nothing but the dead local address is dropped.
  Future<void> stripProxy();

  /// Fully clears the MirrorStages proxy config (the settings-page "清除配置"
  /// action).
  Future<void> clearProxy();

  /// Restores the user's pre-MirrorStages config from the backup taken at
  /// first-time initialization. Throws when there is no backup to restore.
  Future<void> restoreOriginals();

  /// Snapshots the user's pristine config (once) so it can be restored later.
  /// Invoked only for a genuine first-time initialization.
  Future<void> preserveOriginals();
}
