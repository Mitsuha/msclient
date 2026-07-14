import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Owns the running `sing-box` child process: launches it with `run -c <config>`
/// (outbounds/route come from the config file written by [SingboxController]),
/// tees its output to a log file, and kills it on shutdown.
class SingboxProcess {
  SingboxProcess();

  Process? _process;
  IOSink? _logSink;

  bool get isRunning => _process != null;

  /// Spawns sing-box. A no-op if it is already running.
  Future<void> start({
    required String binaryPath,
    required String configPath,
    required String logPath,
  }) async {
    if (_process != null) {
      return;
    }

    final logFile = File(logPath);
    await logFile.parent.create(recursive: true);
    final sink = logFile.openWrite();

    final process = await Process.start(binaryPath, ['run', '-c', configPath]);
    _process = process;
    _logSink = sink;

    _pipe(process.stdout, sink);
    _pipe(process.stderr, sink);

    // If sing-box dies on its own, drop our handle so a later start() can
    // respawn it.
    unawaited(
      process.exitCode.then((code) {
        debugPrint('sing-box exited with code $code');
        if (identical(_process, process)) {
          _process = null;
          _closeLog();
        }
      }),
    );
  }

  /// Kills sing-box and closes the log. Safe to call when not running.
  Future<void> stop() async {
    final process = _process;
    _process = null;
    if (process != null) {
      process.kill();
      // Give the OS a moment to reap it; ignore the exit code.
      await process.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () => -1,
      );
    }
    await _closeLog();
  }

  void _pipe(Stream<List<int>> stream, IOSink sink) {
    stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => sink.writeln(line),
          onError: (_) {},
          cancelOnError: false,
        );
  }

  Future<void> _closeLog() async {
    final sink = _logSink;
    _logSink = null;
    if (sink != null) {
      try {
        await sink.flush();
        await sink.close();
      } catch (_) {
        // The process may have closed the pipe already; nothing to do.
      }
    }
  }
}
