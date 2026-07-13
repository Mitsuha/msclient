/// Application-wide structured logging contract.
///
/// Implementations must not let logging failures escape to callers.
abstract interface class AppLogger {
  Future<void> info(
    String event,
    String message, {
    Map<String, Object?> context = const {},
  });

  Future<void> error(
    String event,
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  });
}
