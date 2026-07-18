import 'dart:async';

/// Runs async actions one at a time, in submission order.
///
/// Every submission waits for the ones before it, so callers can never overlap
/// or race shared state — the app uses one queue to serialize all
/// snapshot-mutating work (foreground actions and the background ticks alike).
/// [isBusy] flips to true synchronously on submit, so a caller can cheaply skip
/// its work when the queue is already occupied (the background ticks do this).
class SerialQueue {
  Future<void> _tail = Future<void>.value();
  int _active = 0;

  /// Whether any submitted action is still pending or running.
  bool get isBusy => _active > 0;

  /// Enqueues [action], returning a future that completes with its result once
  /// every earlier action has finished. A failing action rejects only its own
  /// future; the queue keeps draining.
  Future<T> run<T>(Future<T> Function() action) {
    _active++;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _active--;
      }
    });
    return completer.future;
  }
}
