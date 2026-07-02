import 'package:flutter/foundation.dart';

import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/features/models/control_panel_models.dart';
import 'package:desktop/features/services/control_panel_service.dart';

enum ControlPanelSection { dashboard, settings }

class ControlPanelViewModel extends ChangeNotifier {
  ControlPanelViewModel({required ControlPanelService service})
    : this._(service);

  ControlPanelViewModel._(this._service);

  final ControlPanelService _service;

  ControlPanelSnapshot? _snapshot;
  ControlPanelSection _selectedSection = ControlPanelSection.dashboard;
  bool _isWorking = false;
  bool _isAuthenticated = false;
  bool _isAuthReady = false;
  bool _isLoggingIn = false;
  String? _errorMessage;
  String? _loginErrorMessage;

  ControlPanelSnapshot? get snapshot => _snapshot;
  ControlPanelSection get selectedSection => _selectedSection;
  bool get isWorking => _isWorking;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAuthReady => _isAuthReady;
  bool get isLoggingIn => _isLoggingIn;
  bool get shouldShowLogin => _isAuthReady && !_isAuthenticated;
  String? get errorMessage => _errorMessage;
  String? get loginErrorMessage => _loginErrorMessage;

  Future<void> bootstrap() async {
    _isAuthenticated = await _service.hasSession();
    _isAuthReady = true;
    notifyListeners();

    if (_isAuthenticated) {
      await load();
    }
  }

  Future<void> load() async {
    if (!_isAuthenticated) {
      return;
    }
    await _run(() => _service.loadSnapshot());
  }

  Future<void> refresh() => load();

  void selectSection(ControlPanelSection section) {
    if (_selectedSection == section) {
      return;
    }
    _selectedSection = section;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _run(() async {
      await _service.initializeLocalProxyEnv();
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
    } on ApiException catch (error) {
      _loginErrorMessage = _loginMessageFor(error);
    } catch (error) {
      _loginErrorMessage = '登录失败，请稍后重试。';
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
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

  Future<void> _run(Future<ControlPanelSnapshot> Function() action) async {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _snapshot = await action();
    } on UnauthenticatedException {
      _isAuthenticated = false;
      _snapshot = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
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
