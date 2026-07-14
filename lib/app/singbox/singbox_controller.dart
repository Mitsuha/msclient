import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/singbox/singbox_config_builder.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/data/api/singbox_clash_api.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/singbox_binary.dart';
import 'package:desktop/system/singbox_process.dart';

/// Drives the local sing-box lifecycle: installs the binary, writes a config
/// built from the node list (one http outbound per node behind a selector), runs
/// sing-box against it, and switches the selected node over the Clash API.
///
/// ```
/// CLI tool ──http──▶ 127.0.0.1:proxyPort ──selector──▶ remote MirrorStages node
///           (singboxLocalProxyUrl, constant)          (switched via apply(...))
/// ```
class SingboxController {
  SingboxController({
    required this._binary,
    required this._process,
    required this._api,
    required this._builder,
    required this._home,
    required this._logger,
  });

  final SingboxBinary _binary;
  final SingboxProcess _process;
  final SingboxClashApiClient _api;
  final SingboxConfigBuilder _builder;
  final HomeDirectory _home;
  final AppLogger _logger;

  /// Tail of the reconcile queue; serialized so bootstrap and the 30s refresh
  /// can't race the config write / process (re)launch.
  Future<void> _reconciling = Future<void>.value();
  bool _stopRequested = false;

  /// True once the Clash API answered after our launch.
  bool _apiReady = false;

  /// The outbound set and selected node currently applied, so [apply] can tell a
  /// live selector switch from a full restart.
  List<String>? _appliedSignature;
  String? _appliedDefaultTag;

  bool get isReady => _apiReady;

  /// A live probe of the Clash API, used by the dashboard rather than the cached
  /// [isReady].
  Future<bool> isHealthy() => _api.ping();

  /// Reconciles sing-box against [proxies]/[selectedUrl]: launches it on first
  /// call, restarts it when the node set changed, or just flips the selector
  /// when only the selection changed. Idempotent; serialized internally.
  Future<void> apply(List<ClientProxyOption> proxies, {String? selectedUrl}) {
    final run = _reconciling.then((_) => _apply(proxies, selectedUrl));
    _reconciling = run.catchError((_) {});
    return run;
  }

  Future<void> _apply(
    List<ClientProxyOption> proxies,
    String? selectedUrl,
  ) async {
    if (_stopRequested || proxies.isEmpty) {
      return;
    }
    final target = _builder.build(proxies, selectedUrl: selectedUrl);

    final needRelaunch =
        !_apiReady ||
        !_process.isRunning ||
        !_listEquals(target.outboundSignature, _appliedSignature);
    if (needRelaunch) {
      await _launch(target);
      return;
    }

    // Only the selected node changed: switch it live, then persist the new
    // default into the config file so the next launch honors it.
    if (target.defaultTag != _appliedDefaultTag) {
      try {
        await _api.selectOutbound(
          selector: SingboxConfigBuilder.selectorTag,
          outboundTag: target.defaultTag,
        );
        await _writeConfig(target.json);
        _appliedDefaultTag = target.defaultTag;
      } catch (error, stackTrace) {
        await _logger.error(
          'singbox.select.failed',
          'Switching the sing-box node failed',
          error: error.toString(),
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }
  }

  /// Installs (if needed), writes the config, and (re)starts sing-box against
  /// it, waiting for the Clash API. Honors [_stopRequested] at each async gap.
  Future<void> _launch(SingboxConfig target) async {
    try {
      final binaryPath = await _binary.ensureInstalled();
      if (_stopRequested) {
        return;
      }
      await _writeConfig(target.json);
      // Ensure a fresh process picks up the new config (no-op when not running).
      await _process.stop();
      _apiReady = false;
      if (_stopRequested) {
        return;
      }
      await _process.start(
        binaryPath: binaryPath,
        configPath: await _configPath(),
        logPath: await _logPath(),
      );
      if (_stopRequested) {
        await _process.stop();
        return;
      }
      await _waitForApi();
      if (_stopRequested) {
        return;
      }
      _apiReady = true;
      _appliedSignature = target.outboundSignature;
      _appliedDefaultTag = target.defaultTag;
    } catch (error, stackTrace) {
      if (_stopRequested) {
        return;
      }
      await _logger.error(
        'singbox.start.failed',
        'Sing-box failed to start',
        error: error.toString(),
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Kills sing-box and releases API resources.
  Future<void> stop() async {
    _stopRequested = true;
    await _reconciling.catchError((_) {});
    await _process.stop();
    _api.close();
    _apiReady = false;
    _appliedSignature = null;
    _appliedDefaultTag = null;
  }

  Future<void> _waitForApi() async {
    const attempts = 30;
    for (var i = 0; i < attempts; i++) {
      if (_stopRequested) {
        return;
      }
      if (await _api.ping()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('sing-box Clash API did not come up');
  }

  /// Atomically writes the config to `~/.mstages/sing-box.json`.
  Future<void> _writeConfig(Map<String, dynamic> json) async {
    final path = await _configPath();
    final temp = File('$path.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
    await temp.rename(path);
  }

  Future<String> _configPath() async =>
      '${await _home.resolve()}/${AppConfig.dataDirectoryName}/${AppConfig.singboxConfigFileName}';

  Future<String> _logPath() async =>
      '${await _home.resolve()}/${AppConfig.dataDirectoryName}/sing-box.log';

  static bool _listEquals(List<String> a, List<String>? b) {
    if (b == null || a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
