import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:desktop/system/process_inspector.dart';

enum RuntimeState {
  loading,
  conflict,
  rootCertificateMissing,
  uninitialized,
  running,
  error,
}

/// Everything the UI renders in one immutable value: remote account data plus
/// the state of the local machine.
class AppSnapshot {
  const AppSnapshot({
    required this.state,
    required this.account,
    required this.initialization,
    required this.localConfiguration,
    this.dashboard,
    this.conflicts = const [],
    this.message,
  });

  final RuntimeState state;
  final AccountSummary account;
  final InitializationStatus initialization;
  final LocalConfigurationStatus localConfiguration;
  final DashboardData? dashboard;
  final List<ConflictProcess> conflicts;
  final String? message;

  bool get isBusy => state == RuntimeState.loading;
}
