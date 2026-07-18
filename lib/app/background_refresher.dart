import 'dart:async';

/// Owns the periodic background jobs that run while the user is signed in: a
/// silent snapshot refresh and a silent account rotation.
///
/// This is scheduling only — *what* each tick does (and how it guards against
/// overlapping foreground work) is supplied by the caller. Keeping the timers
/// here, out of the view model, isolates the two "后台任务" from the UI state
/// they feed.
class BackgroundRefresher {
  BackgroundRefresher({
    required this._onRefresh,
    required this._onRotateAccounts,
    this.refreshInterval = const Duration(seconds: 30),
    this.rotateInterval = const Duration(minutes: 1),
  });

  /// How often the snapshot is silently refreshed while signed in.
  final Duration refreshInterval;

  /// How often each initialized tool silently rotates its account. Cheap on the
  /// server: when the current account is still usable it is returned unchanged.
  final Duration rotateInterval;

  final Future<void> Function() _onRefresh;
  final Future<void> Function() _onRotateAccounts;

  Timer? _refreshTimer;
  Timer? _rotateTimer;

  /// (Re)starts both jobs. Safe to call repeatedly; any running timers are
  /// cancelled first.
  void start() {
    stop();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => _onRefresh());
    _rotateTimer = Timer.periodic(rotateInterval, (_) => _onRotateAccounts());
  }

  /// Cancels both jobs. Call on sign-out.
  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _rotateTimer?.cancel();
    _rotateTimer = null;
  }

  void dispose() => stop();
}
