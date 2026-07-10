import 'dart:async';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/data/api/gost_api.dart';
import 'package:desktop/system/gost_binary.dart';
import 'package:desktop/system/gost_process.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter/foundation.dart';

/// Drives the local go-gost lifecycle: installs the binary, launches it with
/// its control API, and points a single forwarding chain at the selected node.
///
/// ```
/// CLI tool ──http──▶ 127.0.0.1:proxyPort ──chain──▶ remote MirrorStages node
///           (gostLocalProxyUrl, constant)          (updated via applyProxyNode)
/// ```
class GostController {
  GostController({
    required this._binary,
    required this._process,
    required this._api,
    required this._home,
    this.host = AppConfig.gostHost,
    this.apiPort = AppConfig.gostApiPort,
    this.proxyPort = AppConfig.gostProxyPort,
  });

  final GostBinary _binary;
  final GostProcess _process;
  final GostApiClient _api;
  final HomeDirectory _home;
  final String host;
  final int apiPort;
  final int proxyPort;

  static const _chainName = 'mstages';
  static const _serviceName = 'mstages-local';
  static const _bypassName = 'mstages-proxy';

  /// Only these domains (and subdomains) are forwarded through the remote node;
  /// everything else is dialed directly (see [_bypassBody]).
  static const _proxyDomains = <String>[
    'chatgpt.com',
    'anthropic.com',
    'openai.com',
    'claude.com',
    'claude.ai',
    'api.anthropic.com',
    'platform.claude.com',
  ];

  Future<void>? _starting;

  /// Tail of the config-push queue; see [_applyNow].
  Future<void> _applying = Future<void>.value();
  bool _stopRequested = false;
  bool _serviceApplied = false;
  bool _bypassApplied = false;

  /// True once the control API answers, whether we spawned gost or adopted one
  /// from a previous session.
  bool _apiReady = false;

  /// The requested node and the live one, kept apart so [applyProxyNode] can
  /// skip redundant calls and apply a node requested before gost was up.
  String? _desiredRemoteUrl;
  String? _appliedRemoteUrl;

  bool get isReady => _apiReady;

  /// A live probe of the control API, used by the dashboard rather than the
  /// cached [isReady].
  Future<bool> isHealthy() => _api.ping();

  /// Installs the binary, launches gost, waits for its API, and applies any
  /// node already requested. Idempotent and safe to call concurrently.
  Future<void> start() {
    if (_starting != null) {
      return _starting!;
    }
    _stopRequested = false;
    return _starting = _start();
  }

  Future<void> _start() async {
    try {
      // Adopt a gost left running by a previous session rather than spawn a
      // second one (which would clash on the port).
      if (!await _api.ping()) {
        if (_stopRequested) {
          return;
        }
        await _spawn();
      }
      if (_stopRequested) {
        await _process.stop();
        return;
      }
      _apiReady = true;
      final desired = _desiredRemoteUrl;
      if (desired != null) {
        await _applyNow(desired);
      }
    } catch (error) {
      if (_stopRequested) {
        return;
      }
      // Let a later start() retry from scratch (e.g. offline first-run download).
      _starting = null;
      debugPrint('gost failed to start: $error');
      rethrow;
    }
  }

  /// Points the forwarding chain at [remoteProxyUrl]. If gost is not up yet the
  /// choice is remembered and applied by [start].
  Future<void> applyProxyNode(String remoteProxyUrl) async {
    _desiredRemoteUrl = remoteProxyUrl;
    if (!_apiReady || remoteProxyUrl == _appliedRemoteUrl) {
      return;
    }
    await _applyNow(remoteProxyUrl);
  }

  /// Kills gost and releases API resources.
  Future<void> stop() async {
    _stopRequested = true;
    final starting = _starting;
    if (starting != null) {
      await starting.catchError((_) {});
    }
    await _process.stop();
    _api.close();
    _starting = null;
    _serviceApplied = false;
    _bypassApplied = false;
    _appliedRemoteUrl = null;
    _apiReady = false;
  }

  /// Downloads (if needed) and launches our own gost process, then waits for
  /// its control API. Honors [_stopRequested] at each async gap.
  Future<void> _spawn() async {
    final binaryPath = await _binary.ensureInstalled();
    if (_stopRequested) {
      return;
    }
    await _process.start(
      binaryPath: binaryPath,
      apiAddress: '$host:$apiPort',
      logPath: await _logPath(),
    );
    if (_stopRequested) {
      await _process.stop();
      return;
    }
    await _waitForApi();
  }

  /// Serializes config pushes: concurrent callers (bootstrap and the snapshot
  /// refresh) would otherwise race [GostApiClient]'s exists-check and POST the
  /// same object twice.
  Future<void> _applyNow(String remoteUrl) {
    final run = _applying.then((_) => _applyGuarded(remoteUrl));
    _applying = run.catchError((_) {});
    return run;
  }

  Future<void> _applyGuarded(String remoteUrl) async {
    if (remoteUrl == _appliedRemoteUrl) {
      return;
    }
    try {
      await _pushConfig(remoteUrl);
    } catch (_) {
      // A gost adopted from a crashed session dies at the first push: its
      // stdio pipes broke with the old parent, and the log write the push
      // provokes kills it (SIGPIPE). If gost is gone and the live process is
      // not ours to begin with, take over: spawn our own and push the whole
      // config from scratch.
      if (_stopRequested || _process.isRunning || await _api.ping()) {
        rethrow;
      }
      _bypassApplied = false;
      _serviceApplied = false;
      _appliedRemoteUrl = null;
      await _spawn();
      if (_stopRequested) {
        return;
      }
      await _pushConfig(remoteUrl);
    }
  }

  Future<void> _pushConfig(String remoteUrl) async {
    // The bypass must exist before the chain that references it by name.
    if (!_bypassApplied) {
      await _api.upsertBypass(_bypassName, _bypassBody());
      _bypassApplied = true;
    }
    await _api.upsertChain(_chainName, _chainBody(remoteUrl));
    if (!_serviceApplied) {
      await _api.upsertService(_serviceName, _serviceBody());
      _serviceApplied = true;
    }
    _appliedRemoteUrl = remoteUrl;
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
    throw TimeoutException('gost control API did not come up');
  }

  Future<String> _logPath() async =>
      '${await _home.resolve()}/${AppConfig.dataDirectoryName}/gost.log';

  /// A local HTTP proxy on the loopback port, forwarding via [_chainName].
  Map<String, dynamic> _serviceBody() => {
    'name': _serviceName,
    'addr': '$host:$proxyPort',
    'handler': {'type': 'http', 'chain': _chainName},
    'listener': {'type': 'tcp'},
  };

  /// A single-hop chain to [remoteUrl]: `https` nodes are dialed over TLS, and
  /// the upstream is spoken to as an HTTP proxy (CONNECT).
  Map<String, dynamic> _chainBody(String remoteUrl) {
    final uri = Uri.parse(remoteUrl);
    final overTls = uri.scheme == 'https';
    final port = uri.hasPort ? uri.port : (overTls ? 443 : 80);
    return {
      'name': _chainName,
      'hops': [
        {
          'name': '$_chainName-hop',
          'nodes': [
            {
              'name': '$_chainName-node',
              'addr': '${uri.host}:$port',
              'connector': {'type': 'http'},
              'dialer': {'type': overTls ? 'tls' : 'tcp'},
              'bypasses': [_bypassName],
            },
          ],
        },
      ],
    };
  }

  /// A whitelist-mode bypass: it matches (and so skips the chain node) for every
  /// target except [_proxyDomains] and their subdomains, leaving only those
  /// forwarded to the remote node.
  Map<String, dynamic> _bypassBody() {
    final matchers = <String>[
      for (final domain in _proxyDomains) ...[domain, '*.$domain'],
    ];
    return {'name': _bypassName, 'whitelist': true, 'matchers': matchers};
  }
}
