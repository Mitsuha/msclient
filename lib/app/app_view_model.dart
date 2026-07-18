import 'dart:async';

import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/background_refresher.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/billing_outcome.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/core/utils/serial_queue.dart';
import 'package:desktop/domain/tools/tool.dart';
import 'package:flutter/foundation.dart';

class AppViewModel extends ChangeNotifier {
  AppViewModel({required AppService service, required AppLogger logger})
    : this._(service, logger);

  AppViewModel._(this._service, this._logger) {
    _refresher = BackgroundRefresher(
      onRefresh: _autoRefresh,
      onRotateAccounts: _autoSwitch,
    );
  }

  final AppService _service;
  final AppLogger _logger;

  /// Serializes every snapshot-mutating operation — foreground actions and the
  /// background ticks — so they never overlap or race over [_snapshot]. A
  /// background tick simply skips itself while the queue is busy.
  final SerialQueue _queue = SerialQueue();

  /// The two background jobs (30s refresh, 60s account rotation); only running
  /// while authenticated.
  late final BackgroundRefresher _refresher;

  AppSnapshot? _snapshot;
  NavSection _selectedSection = NavSection.dashboard;
  bool _isWorking = false;
  bool _isAuthenticated = false;
  bool _isAuthReady = false;
  bool _isLoggingIn = false;
  String? _errorMessage;
  String? _loginErrorMessage;

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
    // Launch the local proxy in the background; first run may download the
    // sing-box binary, so this must not block the login UI.
    final proxyStartup = _service.startProxy();

    _isAuthenticated = await _service.hasSession();
    _isAuthReady = true;
    notifyListeners();

    // Restore the proxy config stripped on the previous quit, for any tool
    // whose on-disk credentials are still a MirrorStages-issued account. Awaited
    // here — after the login screen has rendered above, but before anything
    // reads tool status — so the initialization check never observes a
    // half-written config. Local file IO only; the proxy is already starting in
    // the background, so this does not delay the UI.
    await _service.reapplyIssuedProxyConfig();

    unawaited(_refreshWhenProxyStarted(proxyStartup));

    if (_isAuthenticated) {
      await load();
      _refresher.start();
    }
  }

  Future<void> _refreshWhenProxyStarted(Future<void> startup) async {
    try {
      await startup;
      await _autoRefresh();
    } catch (_) {
      // startProxy is best-effort; the periodic refresh can retry health later.
    }
  }

  /// Tears down background work and stops the local proxy. Call before the app
  /// really quits (the tray "退出" item / a forced destroy).
  Future<void> shutdown() async {
    _refresher.stop();
    await _service.stripToolProxyConfig();
    await _service.stopProxy();
  }

  Future<void> load() async {
    if (!_isAuthenticated) {
      return;
    }
    await _run(_service.loadSnapshot);
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
  Future<BillingOutcome> applyCodexBilling(int userPackId) =>
      _applyBilling(ToolId.codex, userPackId);

  /// Applies the chosen billing method to Claude Code. See [applyCodexBilling].
  Future<BillingOutcome> applyClaudeBilling(int userPackId) =>
      _applyBilling(ToolId.claude, userPackId);

  /// Persists the chosen node and switches sing-box's selector to it.
  Future<void> selectProxy(String url) async {
    await _run(() async {
      await _service.selectProxy(url);
      return _service.loadSnapshot();
    });
  }

  /// Re-applies a single Codex initialization step from the settings page.
  Future<void> applyCodexInitStep(String stepId) =>
      _applyInitStep(ToolId.codex, stepId);

  /// Re-applies a single Claude Code initialization step from the settings page.
  Future<void> applyClaudeInitStep(String stepId) =>
      _applyInitStep(ToolId.claude, stepId);

  /// Clears the MirrorStages proxy configuration from the local tool configs
  /// (Claude Code `settings.json` proxy entries, Codex `.env`).
  Future<void> clearProxyConfig() async {
    await _run(() async {
      await _service.clearProxyConfig();
      return _service.loadSnapshot();
    });
  }

  Future<void> restoreCodexConfig() => _restoreToolConfig(ToolId.codex);

  Future<void> restoreClaudeConfig() => _restoreToolConfig(ToolId.claude);

  Future<void> installRootCertificate() async {
    await _run(() async {
      await _service.installRootCertificate();
      return _service.loadSnapshot();
    });
  }

  Future<void> _applyInitStep(ToolId id, String stepId) async {
    await _run(() async {
      await _service.applyToolInitStep(id, stepId);
      return _service.loadSnapshot();
    });
  }

  Future<void> _restoreToolConfig(ToolId id) async {
    await _run(() async {
      await _service.restoreToolConfig(id);
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
      _refresher.start();
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
    _refresher.stop();
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

  /// Runs a billing re-allocation like [_run], but reports its outcome as a
  /// [BillingOutcome] so the card can react per-case. An empty account pool
  /// (`no_available_account`) is surfaced by the caller as a dedicated dialog,
  /// so it is *not* raised into [errorMessage]; every other failure still is.
  Future<BillingOutcome> _applyBilling(ToolId id, int userPackId) async {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _snapshot = await _queue.run(() async {
        await _service.initializeTool(id, userPackId: userPackId);
        return _service.loadSnapshot();
      });
      return BillingOutcome.success;
    } on UnauthenticatedException {
      _handleSignedOut();
      return BillingOutcome.failed;
    } on ApiException catch (error) {
      if (error.error == 'api.error.no_available_account') {
        return BillingOutcome.noAvailableAccount;
      }
      _errorMessage = error.toString();
      return BillingOutcome.failed;
    } catch (error) {
      _errorMessage = error.toString();
      return BillingOutcome.failed;
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }

  /// Runs [action] on the serial queue with the working flag raised, capturing
  /// failures into [errorMessage]. Returns true when [action] completed without
  /// error.
  Future<bool> _run(Future<AppSnapshot> Function() action) async {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    var succeeded = false;
    try {
      _snapshot = await _queue.run(action);
      succeeded = true;
    } on UnauthenticatedException {
      _handleSignedOut();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
    return succeeded;
  }

  /// Reloads the snapshot in the background without raising the working flag, so
  /// the periodic refresh never flashes spinners or disables controls. Skipped
  /// while a foreground action or another queued job is still running.
  Future<void> _autoRefresh() async {
    if (!_isAuthenticated || _queue.isBusy) {
      return;
    }
    try {
      _snapshot = await _queue.run(_service.loadSnapshot);
      _errorMessage = null;
      notifyListeners();
    } on UnauthenticatedException {
      _handleSignedOut();
      notifyListeners();
    } catch (_) {
      // Transient failure: keep the last good snapshot and try again next tick.
    }
  }

  /// Silently rotates the account of every *initialized* tool, reusing the pack
  /// its current credentials are billed against (0 = pay-as-you-go / 按量计费).
  /// Runs without raising the working flag, so it never flashes spinners;
  /// skipped while any other queued job is running. A tool that isn't
  /// initialized is left untouched.
  Future<void> _autoSwitch() async {
    final snapshot = _snapshot;
    if (!_isAuthenticated || _queue.isBusy || snapshot == null) {
      return;
    }
    final initialized = ToolId.values
        .where((id) => snapshot.statusFor(id).isInitialized)
        .toList();
    if (initialized.isEmpty) {
      return;
    }
    try {
      _snapshot = await _queue.run(() async {
        for (final id in initialized) {
          await _service.initializeTool(
            id,
            userPackId: snapshot.statusFor(id).account?.userPackId ?? 0,
          );
        }
        return _service.loadSnapshot();
      });
      notifyListeners();
    } on UnauthenticatedException {
      _handleSignedOut();
      notifyListeners();
    } catch (_) {
      // Best-effort rotation (e.g. an empty account pool): keep the last good
      // snapshot and try again next tick.
    }
  }

  /// Common reaction to a 401 mid-operation: stop background work and drop to
  /// the login screen.
  void _handleSignedOut() {
    _refresher.stop();
    _isAuthenticated = false;
    _snapshot = null;
  }

  @override
  void dispose() {
    _refresher.dispose();
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
