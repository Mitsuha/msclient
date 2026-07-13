import 'dart:async';

import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

class AppViewModel extends ChangeNotifier {
  AppViewModel({required AppService service, required AppLogger logger})
    : this._(service, logger);

  AppViewModel._(this._service, this._logger);

  final AppService _service;
  final AppLogger _logger;

  /// How often the snapshot is silently refreshed while signed in.
  static const _autoRefreshInterval = Duration(seconds: 30);

  AppSnapshot? _snapshot;
  NavSection _selectedSection = NavSection.dashboard;
  bool _isWorking = false;
  bool _isAuthenticated = false;
  bool _isAuthReady = false;
  bool _isLoggingIn = false;
  String? _errorMessage;
  String? _loginErrorMessage;

  /// Periodic background refresh; only runs while authenticated.
  Timer? _autoRefreshTimer;

  /// True while a silent auto-refresh is in flight, so ticks never overlap.
  bool _isAutoRefreshing = false;

  AppSnapshot? get snapshot => _snapshot;
  NavSection get selectedSection => _selectedSection;
  bool get isWorking => _isWorking;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAuthReady => _isAuthReady;
  bool get isLoggingIn => _isLoggingIn;
  bool get shouldShowLogin => _isAuthReady && !_isAuthenticated;
  String? get errorMessage => _errorMessage;
  String? get loginErrorMessage => _loginErrorMessage;

  Future<void> bootstrap() async {
    // Launch the local proxy in the background; first run downloads the gost
    // binary, so this must not block the login UI.
    unawaited(_service.startGost());

    _isAuthenticated = await _service.hasSession();
    _isAuthReady = true;
    notifyListeners();

    if (_isAuthenticated) {
      await load();
      _startAutoRefresh();
    }
  }

  /// Tears down background work and stops the local proxy. Call before the app
  /// really quits (the tray "退出" item / a forced destroy).
  Future<void> shutdown() async {
    _stopAutoRefresh();
    await _service.stopGost();
  }

  Future<void> load() async {
    if (!_isAuthenticated) {
      return;
    }
    await _run(() => _service.loadSnapshot());
  }

  Future<void> refresh() => load();

  void selectSection(NavSection section) {
    if (_selectedSection == section) {
      return;
    }
    _selectedSection = section;
    notifyListeners();
  }

  /// Applies the chosen billing method to Codex by rewriting its credentials.
  /// [userPackId] is 0 for pay-as-you-go (按量计费) or a subscription pack id.
  /// Returns true when the credentials were rewritten successfully.
  Future<bool> applyCodexBilling(int userPackId) {
    return _run(() async {
      await _service.initializeLocalProxyEnv(userPackId: userPackId);
      return _service.loadSnapshot();
    });
  }

  /// Applies the chosen billing method to Claude Code by rewriting its
  /// credentials. [userPackId] is 0 for pay-as-you-go (按量计费) or a
  /// subscription pack id. Returns true when the credentials were rewritten
  /// successfully.
  Future<bool> applyClaudeBilling(int userPackId) {
    return _run(() async {
      await _service.initializeClaude(userPackId: userPackId);
      return _service.loadSnapshot();
    });
  }

  /// Persists the chosen node and re-points gost's chain at it.
  Future<void> selectProxy(String url) async {
    await _run(() async {
      await _service.selectProxy(url);
      return _service.loadSnapshot();
    });
  }

  /// Re-applies a single Codex initialization step from the settings page.
  Future<void> applyCodexInitStep(String stepId) async {
    await _run(() async {
      await _service.applyCodexInitStep(stepId);
      return _service.loadSnapshot();
    });
  }

  /// Re-applies a single Claude Code initialization step from the settings
  /// page.
  Future<void> applyClaudeInitStep(String stepId) async {
    await _run(() async {
      await _service.applyClaudeInitStep(stepId);
      return _service.loadSnapshot();
    });
  }

  /// Clears the MirrorStages proxy configuration from the local tool configs
  /// (Claude Code `settings.json` proxy entries, Codex `.env`).
  Future<void> clearProxyConfig() async {
    await _run(() async {
      await _service.clearProxyConfig();
      return _service.loadSnapshot();
    });
  }

  Future<void> restoreCodexConfig() async {
    await _run(() async {
      await _service.restoreOriginalConfig();
      return _service.loadSnapshot();
    });
  }

  Future<void> restoreClaudeConfig() async {
    await _run(() async {
      await _service.restoreClaudeConfig();
      return _service.loadSnapshot();
    });
  }

  Future<void> installRootCertificate() async {
    await _run(() async {
      await _service.installRootCertificate();
      return _service.loadSnapshot();
    });
  }

  Future<void> login({
    required String account,
    required String password,
  }) async {
    if (account.trim().isEmpty || password.isEmpty) {
      _loginErrorMessage = '请输入账号和密码。';
      notifyListeners();
      return;
    }

    _isLoggingIn = true;
    _loginErrorMessage = null;
    notifyListeners();

    try {
      await _service.login(account: account, password: password);
      _isAuthenticated = true;
      _snapshot = null;
      await load();
      _startAutoRefresh();
    } on ApiException catch (error) {
      _loginErrorMessage = _loginMessageFor(error);
    } catch (error, stackTrace) {
      await _logger.error(
        'auth.login.failed',
        'Login failed unexpectedly',
        error: error.toString(),
        stackTrace: stackTrace,
        context: {'account': account},
      );
      _loginErrorMessage = '登录失败，请稍后重试。';
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopAutoRefresh();
    await _service.logout();
    _snapshot = null;
    _isAuthenticated = false;
    _errorMessage = null;
    _loginErrorMessage = null;
    notifyListeners();
  }

  Future<void> openAdminConsole() async {
    await _service.openAdminConsole();
  }

  /// Runs [action] with the working flag raised, capturing failures into
  /// [errorMessage]. Returns true when [action] completed without error.
  Future<bool> _run(Future<AppSnapshot> Function() action) async {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    var succeeded = false;
    try {
      _snapshot = await action();
      succeeded = true;
    } on UnauthenticatedException {
      _stopAutoRefresh();
      _isAuthenticated = false;
      _snapshot = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
    return succeeded;
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) => _autoRefresh(),
    );
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Reloads the snapshot in the background without raising the working flag,
  /// so the periodic refresh never flashes spinners or disables controls. Ticks
  /// are skipped while a foreground action or a previous tick is still running.
  Future<void> _autoRefresh() async {
    if (!_isAuthenticated || _isWorking || _isAutoRefreshing) {
      return;
    }
    _isAutoRefreshing = true;
    try {
      _snapshot = await _service.loadSnapshot();
      _errorMessage = null;
      notifyListeners();
    } on UnauthenticatedException {
      _stopAutoRefresh();
      _isAuthenticated = false;
      _snapshot = null;
      notifyListeners();
    } catch (_) {
      // Transient failure: keep the last good snapshot and try again next tick.
    } finally {
      _isAutoRefreshing = false;
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  String _loginMessageFor(ApiException error) {
    return switch (error.error) {
      'api.error.wrong_credentials' => '账号或密码不正确，请检查后重试。',
      'api.error.phone_or_email_required' => '请输入邮箱或手机号。',
      'api.error.bad_request' => '请检查账号和密码格式。',
      'api.error.unauthorized' => '登录状态无效，请重新登录。',
      _ when error.statusCode == 403 => '账号或密码不正确，请检查后重试。',
      _ when error.statusCode >= 500 => '服务暂时不可用，请稍后重试。',
      _ => '登录失败，请稍后重试。',
    };
  }
}
