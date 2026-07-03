import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/app/models/tool_status.dart';
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
    this.message,
  });

  final EnvironmentStatus environment;
  final AccountSummary account;
  final ToolStatus codex;
  final ToolStatus claude;
  final LocalConfigurationStatus localConfiguration;
  final DashboardData? dashboard;
  final List<ConflictProcess> conflicts;
  final String? message;

  bool get isBusy => environment == EnvironmentStatus.loading;
}
