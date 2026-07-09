/// One independently checkable / appliable unit of a tool's MirrorStages
/// initialization (e.g. "write the proxy env", "write the credentials").
///
/// [check] verifies the step's on-disk state without touching anything;
/// [apply] (re)writes it. Both are self-contained closures so a step can be
/// repaired on its own from the settings page.
class InitStep {
  const InitStep({
    required this.id,
    required this.title,
    required this.description,
    required this.check,
    required this.apply,
  });

  final String id;
  final String title;
  final String description;
  final Future<bool> Function() check;
  final Future<void> Function() apply;
}

/// The outcome of checking one [InitStep], snapshot-friendly for the UI.
class InitStepStatus {
  const InitStepStatus({
    required this.id,
    required this.title,
    required this.description,
    required this.passed,
  });

  final String id;
  final String title;
  final String description;
  final bool passed;
}

/// Runs a tool's initialization [steps] — all of them in order (dashboard
/// "初始化"), or checked / applied one at a time (settings page).
class ToolInitializer {
  const ToolInitializer(this.steps, {this.preserveOriginals});

  final List<InitStep> steps;

  /// Snapshots the user's pristine config into `old_config` (once) so it can be
  /// restored later. Only invoked by [initialize] when [initialize] is asked to
  /// back up — no other entry point creates `old_config`, so re-initializing,
  /// changing billing, single-step repair, and proxy switching never touch it.
  final Future<void> Function()? preserveOriginals;

  /// Applies every step in order, unconditionally, so a full initialization
  /// always ends in a known-good state.
  ///
  /// [backupOriginals] runs [preserveOriginals] first; it should be true only
  /// for a genuine first-time initialization (the dashboard "初始化"), so that
  /// the backup captures the user's original files rather than a
  /// MirrorStages-written one.
  Future<void> initialize({bool backupOriginals = false}) async {
    if (backupOriginals) {
      await preserveOriginals?.call();
    }
    for (final step in steps) {
      await step.apply();
    }
  }

  /// Checks every step without modifying anything.
  Future<List<InitStepStatus>> checkSteps() async {
    return [
      for (final step in steps)
        InitStepStatus(
          id: step.id,
          title: step.title,
          description: step.description,
          passed: await step.check(),
        ),
    ];
  }

  /// Applies the single step identified by [id].
  Future<void> applyStep(String id) async {
    for (final step in steps) {
      if (step.id == id) {
        await step.apply();
        return;
      }
    }
    throw ArgumentError.value(id, 'id', '未知的初始化步骤');
  }
}
