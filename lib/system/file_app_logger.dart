import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter/foundation.dart';

/// Writes application logs as one JSON object per line.
///
/// Files rotate on the local calendar date and the most recent seven calendar
/// days are retained. All writes are serialized so concurrent callers cannot
/// interleave entries.
class FileAppLogger implements AppLogger {
  FileAppLogger({required this._home, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final HomeDirectory _home;
  final DateTime Function() _now;

  Future<void> _tail = Future<void>.value();
  String? _lastCleanupDate;

  @override
  Future<void> info(
    String event,
    String message, {
    Map<String, Object?> context = const {},
  }) =>
      _enqueue(level: 'info', event: event, message: message, context: context);

  @override
  Future<void> error(
    String event,
    String message, {
    String? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) => _enqueue(
    level: 'error',
    event: event,
    message: message,
    context: context,
    error: error,
    stackTrace: stackTrace,
  );

  Future<void> _enqueue({
    required String level,
    required String event,
    required String message,
    required Map<String, Object?> context,
    String? error,
    StackTrace? stackTrace,
  }) {
    final operation = _tail.then(
      (_) => _write(
        level: level,
        event: event,
        message: message,
        context: context,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    _tail = operation;
    return operation;
  }

  Future<void> _write({
    required String level,
    required String event,
    required String message,
    required Map<String, Object?> context,
    String? error,
    StackTrace? stackTrace,
  }) async {
    try {
      final timestamp = _now();
      final date = _formatDate(timestamp);
      final directory = Directory(
        '${await _home.resolve()}/${AppConfig.dataDirectoryName}/logs',
      );
      await directory.create(recursive: true);
      await _cleanupOncePerDay(directory, timestamp, date);

      final entry = <String, Object?>{
        'timestamp': timestamp.toIso8601String(),
        'level': level,
        'event': event,
        'message': message,
        'context': context,
        'error': ?error,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      };
      final file = File('${directory.path}/app-$date.log');
      await file.writeAsString(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (logError, logStackTrace) {
      debugPrint('application log write failed: $logError\n$logStackTrace');
    }
  }

  Future<void> _cleanupOncePerDay(
    Directory directory,
    DateTime timestamp,
    String date,
  ) async {
    if (_lastCleanupDate == date) {
      return;
    }
    _lastCleanupDate = date;

    final oldestRetainedDay = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day - 6,
    );
    final pattern = RegExp(r'^app-(\d{4})-(\d{2})-(\d{2})\.log$');

    try {
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }
        final match = pattern.firstMatch(entity.uri.pathSegments.last);
        if (match == null) {
          continue;
        }
        final fileDay = DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        );
        if (fileDay.isBefore(oldestRetainedDay)) {
          await entity.delete();
        }
      }
    } catch (cleanupError, cleanupStackTrace) {
      debugPrint(
        'application log cleanup failed: $cleanupError\n$cleanupStackTrace',
      );
    }
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
