import 'package:desktop/app/models/tool_status.dart';

/// The shared contract for a local AI CLI tool's on-disk configuration: where
/// it lives, whether it is installed, and its MirrorStages initialization
/// state. Each tool (Codex, Claude Code) owns all of its own detection behind
/// this interface.
abstract interface class ToolConfigManager {
  /// The tool's configuration directory (e.g. `~/.codex`, `~/.claude`).
  Future<String> directoryPath();

  /// Whether the tool's configuration directory exists on this machine.
  Future<bool> isInstalled();

  /// Reads the stored credentials and reports the initialization state. Any
  /// failure is treated as [ToolStatus.uninitialized] rather than surfaced.
  Future<ToolStatus> readStatus();
}
