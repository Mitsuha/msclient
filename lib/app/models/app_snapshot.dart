import 'package:desktop/app/initialization/tool_initializer.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:desktop/system/process_inspector.dart';

/// Health of the global runtime environment MirrorStages depends on: no
/// conflicting software running and the root certificate trusted. Each tool's
/// own initialization state is tracked separately in [ToolStatus].
enum EnvironmentStatus {
  loading,
  conflict,
  rootCertificateMissing,
  error,
  ready,
}

/// Everything the UI renders in one immutable value: remote account data plus
/// the state of the local machine.
class AppSnapshot {
  const AppSnapshot({
    required this.environment,
    required this.account,
    required this.codex,
    required this.claude,
    required this.localConfiguration,
    this.dashboard,
    this.conflicts = const [],
    this.proxyOptions = const [],
    this.selectedProxyUrl,
    this.codexInitSteps = const [],
    this.claudeInitSteps = const [],
    this.isProxyRunning = false,
    this.message,
  });

  final EnvironmentStatus environment;
  final AccountSummary account;
  final ToolStatus codex;
  final ToolStatus claude;
  final LocalConfigurationStatus localConfiguration;
  final DashboardData? dashboard;
  final List<ConflictProcess> conflicts;

  /// Whether the local sing-box proxy is up. The tools route through it, so a
  /// tool only counts as "running" when it is initialized *and* this is true.
  final bool isProxyRunning;

  /// Proxy nodes fetched from the server (already sorted; first is the
  /// default) and the url currently in effect for initialization.
  final List<ClientProxyOption> proxyOptions;
  final String? selectedProxyUrl;

  /// Per-step check results of each tool's initialization, in step order, so
  /// the settings page can verify and repair steps individually.
  final List<InitStepStatus> codexInitSteps;
  final List<InitStepStatus> claudeInitSteps;

  final String? message;

  bool get isBusy => environment == EnvironmentStatus.loading;
}
