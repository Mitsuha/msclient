import 'dart:convert';
import 'dart:io';

import 'package:desktop/system/platform_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ConflictProcess {
  const ConflictProcess({required this.pid, required this.command});

  final int pid;
  final String command;
}

/// Finds running `cc-switch` processes that conflict with this app's
/// management of the local Codex configuration.
class ConflictProcessInspector {
  const ConflictProcessInspector({this._channel = processInspectorChannel});

  final MethodChannel _channel;

  Future<List<ConflictProcess>> findConflicts() async {
    if (Platform.isMacOS) {
      return _findViaChannel();
    }

    if (Platform.isWindows) {
      return _findViaTasklist();
    }

    return _findViaPs();
  }

  Future<List<ConflictProcess>> _findViaChannel() async {
    final results = await _channel.invokeListMethod<Object?>(
      'findConflictProcesses',
    );
    if (results == null) {
      return const [];
    }

    return results
        .whereType<Map<Object?, Object?>>()
        .map((item) {
          final pidValue = item['pid'];
          return ConflictProcess(
            pid: pidValue is int ? pidValue : int.tryParse('$pidValue') ?? 0,
            command: item['command']?.toString() ?? 'cc-switch',
          );
        })
        .where((item) => item.pid > 0)
        .toList();
  }

  Future<List<ConflictProcess>> _findViaPs() async {
    final result = await Process.run('ps', ['-ef']);
    if (result.exitCode != 0) {
      throw ProcessException('ps', const ['-ef'], result.stderr.toString());
    }

    final currentPid = pid;
    final conflicts = <ConflictProcess>[];
    for (final line in result.stdout.toString().split('\n')) {
      if (!line.contains('cc-switch')) {
        continue;
      }
      if (line.contains('grep cc-switch')) {
        continue;
      }

      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 8) {
        continue;
      }

      final processPid = int.tryParse(parts[1]);
      if (processPid == null || processPid == currentPid) {
        continue;
      }

      conflicts.add(
        ConflictProcess(pid: processPid, command: parts.skip(7).join(' ')),
      );
    }

    return conflicts;
  }

  Future<List<ConflictProcess>> _findViaTasklist() async {
    final result = await Process.run('tasklist.exe', ['/fo', 'csv', '/nh']);
    if (result.exitCode != 0) {
      throw ProcessException(
        'tasklist.exe',
        const ['/fo', 'csv', '/nh'],
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final conflicts = <ConflictProcess>[];
    for (final row in const LineSplitter().convert(result.stdout.toString())) {
      final columns = parseCsvRow(row);
      if (columns.length < 2) {
        continue;
      }

      final imageName = columns[0];
      if (!imageName.toLowerCase().contains('cc-switch')) {
        continue;
      }

      final processPid = int.tryParse(columns[1]);
      if (processPid == null || processPid == pid) {
        continue;
      }

      conflicts.add(ConflictProcess(pid: processPid, command: imageName));
    }

    return conflicts;
  }
}

@visibleForTesting
List<String> parseCsvRow(String row) {
  final values = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < row.length; index += 1) {
    final char = row[index];
    if (char == '"') {
      if (inQuotes && index + 1 < row.length && row[index + 1] == '"') {
        buffer.write('"');
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      values.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }

  values.add(buffer.toString());
  return values;
}
