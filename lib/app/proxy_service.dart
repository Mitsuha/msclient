import 'dart:async';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/singbox/singbox_controller.dart';
import 'package:desktop/data/api/desktop_config_api.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:desktop/data/preferences/network_proxy_store.dart';
import 'package:desktop/data/preferences/proxy_preference_store.dart';
import 'package:desktop/system/port_probe.dart';
import 'package:flutter/foundation.dart';

/// The proxy node list fetched from the server and the node currently in
/// effect. The default (when nothing is saved) is the server-sorted first
/// option. [networkProxyUrl] is the optional upstream HTTP proxy the fallback
/// (direct) traffic is routed through.
class ProxyState {
  const ProxyState({
    this.options = const [],
    this.selectedUrl,
    this.networkProxyUrl,
  });

  final List<ClientProxyOption> options;
  final String? selectedUrl;
  final String? networkProxyUrl;
}

/// Owns the local sing-box proxy: node discovery, the persisted node choice,
/// and keeping sing-box aligned with them.
///
/// Tools always point at the constant [localProxyUrl]; node selection happens
/// inside sing-box via its selector, so switching a node never rewrites any
/// tool config. This is the only place that talks to [SingboxController].
class ProxyService {
  ProxyService({
    required this._singbox,
    required this._configApi,
    required this._preferences,
    required this._networkProxy,
  });

  final SingboxController _singbox;
  final DesktopConfigApi _configApi;
  final ProxyPreferenceStore _preferences;
  final NetworkProxyStore _networkProxy;

  /// The most recent node list, so [select] can rebuild the config against the
  /// full set of outbounds without re-fetching.
  List<ClientProxyOption> _lastOptions = const [];

  /// The most recent upstream network-proxy url, so [select] can rebuild the
  /// config without re-reading it from disk.
  String? _lastNetworkProxyUrl;

  /// The local proxy port auto-detected on first launch (a running Clash-style
  /// upstream). Fixed by product decision, not configurable.
  static const _autofillHost = '127.0.0.1';
  static const _autofillPort = 7890;
  static const _autofillUrl = 'http://$_autofillHost:$_autofillPort';

  /// The constant local proxy every tool's config points at.
  String get localProxyUrl => AppConfig.singboxLocalProxyUrl;

  /// Launches sing-box with an outbound per node and the selected node active.
  /// Best-effort: never throws, so a failure (e.g. offline first run) can't
  /// block the app; the periodic [reconcile] retries later.
  Future<void> start() async {
    try {
      final state = await _resolveState();
      await _singbox.apply(
        _orFallback(state.options),
        selectedUrl: state.selectedUrl,
        networkProxyUrl: state.networkProxyUrl,
      );
    } catch (error) {
      debugPrint('proxy.start failed: $error');
    }
  }

  /// Stops the local sing-box process. Call on app shutdown.
  Future<void> stop() => _singbox.stop();

  /// Whether the local proxy is up right now (live probe).
  Future<bool> isHealthy() => _singbox.isHealthy();

  /// Loads the current node list + selection and keeps sing-box aligned:
  /// restarts when the outbound set changed, flips the selector when only the
  /// choice did, no-ops when unchanged. The apply is best-effort and not
  /// awaited, so a dead sing-box can't block a snapshot; returns the state for
  /// the snapshot.
  Future<ProxyState> reconcile() async {
    final state = await _resolveState();
    unawaited(
      _singbox
          .apply(
            _orFallback(state.options),
            selectedUrl: state.selectedUrl,
            networkProxyUrl: state.networkProxyUrl,
          )
          .catchError(
            (Object error) => debugPrint('singbox.apply failed: $error'),
          ),
    );
    return state;
  }

  /// Persists the picked node and flips sing-box's selector to it. Returns the
  /// resulting state.
  Future<ProxyState> select(String url) async {
    await _preferences.save(url);
    await _singbox.apply(
      _orFallback(_lastOptions),
      selectedUrl: url,
      networkProxyUrl: _lastNetworkProxyUrl,
    );
    return ProxyState(
      options: _lastOptions,
      selectedUrl: url,
      networkProxyUrl: _lastNetworkProxyUrl,
    );
  }

  /// Persists the upstream network proxy url (empty clears it) and rebuilds the
  /// sing-box config so the fallback traffic routes through it (or back to
  /// direct). Returns the resulting state.
  Future<ProxyState> setNetworkProxy(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await _networkProxy.clear();
      _lastNetworkProxyUrl = null;
    } else {
      await _networkProxy.save(trimmed);
      _lastNetworkProxyUrl = trimmed;
    }
    final selectedUrl = await _selectedUrlFor(_lastOptions);
    await _singbox.apply(
      _orFallback(_lastOptions),
      selectedUrl: selectedUrl,
      networkProxyUrl: _lastNetworkProxyUrl,
    );
    return ProxyState(
      options: _lastOptions,
      selectedUrl: selectedUrl,
      networkProxyUrl: _lastNetworkProxyUrl,
    );
  }

  /// On the very first launch, detects a running local HTTP proxy on
  /// [_autofillPort] and, if present, seeds the network-proxy setting with it so
  /// direct traffic goes through the user's existing proxy out of the box. Runs
  /// exactly once (gated by a persisted flag), best-effort, before the proxy is
  /// started so the first config already honors it.
  Future<void> autofillNetworkProxyOnFirstLaunch() async {
    try {
      if (await _networkProxy.isAutofillDone()) {
        return;
      }
      if (await isTcpPortOpen(_autofillHost, _autofillPort)) {
        await _networkProxy.save(_autofillUrl);
      }
      await _networkProxy.markAutofillDone();
    } catch (error) {
      debugPrint('proxy.autofill failed: $error');
    }
  }

  Future<ProxyState> _resolveState() async {
    final options = await _loadOptions();
    _lastNetworkProxyUrl = await _networkProxy.load();
    return ProxyState(
      options: options,
      selectedUrl: await _selectedUrlFor(options),
      networkProxyUrl: _lastNetworkProxyUrl,
    );
  }

  Future<List<ClientProxyOption>> _loadOptions() async {
    try {
      return _lastOptions = await _configApi.clientProxies();
    } catch (_) {
      return const [];
    }
  }

  /// The saved choice wins while the server still offers it; otherwise the
  /// server-sorted first option is the default.
  Future<String?> _selectedUrlFor(List<ClientProxyOption> options) async {
    final saved = await _preferences.load();
    if (saved != null && options.any((option) => option.url == saved)) {
      return saved;
    }
    return options.isEmpty ? null : options.first.url;
  }

  /// Guarantees a non-empty node list so the config always has at least one
  /// outbound: the built-in [AppConfig.proxyUrl] stands in when the server list
  /// is empty/unavailable.
  List<ClientProxyOption> _orFallback(List<ClientProxyOption> options) =>
      options.isEmpty
      ? const [ClientProxyOption(name: 'default', url: AppConfig.proxyUrl)]
      : options;
}
