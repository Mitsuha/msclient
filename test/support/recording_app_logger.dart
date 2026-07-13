import 'package:desktop/core/logging/app_logger.dart';

class RecordedLogEntry {
  const RecordedLogEntry({
    required this.level,
    required this.event,
    required this.message,
    required this.context,
    this.error,
    this.stackTrace,
  });

  final String level;
  final String event;
  final String message;
  final Map<String, Object?> context;
  final String? error;
  final StackTrace? stackTrace;
}

class RecordingAppLogger implements AppLogger {
  final entries = <RecordedLogEntry>[];

  @override
  Future<void> info(
    String event,
    String message, {
    Map<String, Object?> context = const {},
  }) async {
    entries.add(
      RecordedLogEntry(
        level: 'info',
        event: event,
        message: message,
        context: context,
      ),
    );
  }

  @override
  Future<void> error(
    String event,
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) async {
    entries.add(
      RecordedLogEntry(
        level: 'error',
        event: event,
        message: message,
        context: context,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
