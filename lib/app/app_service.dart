import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/api/auth_api.dart';
import 'package:desktop/data/api/codex_auth_api.dart';
import 'package:desktop/data/api/dashboard_api.dart';
import 'package:desktop/data/api/user_pack_api.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/session/session_store.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:desktop/system/external_browser.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/process_inspector.dart';
import 'package:desktop/system/root_certificate_manager.dart';
import 'package:flutter/foundation.dart';

/// Facade the view model talks to: orchestrates the remote APIs (data/) and
/// the local machine integrations (system/) into snapshots and actions.
class AppService {
  AppService({
    required this._sessionStore,
    required this._authApi,
    required this._codexAuthApi,
    required this._dashboardApi,
    required this._userPackApi,
    required this._processInspector,
    required this._rootCertificate,
    required this._codexConfig,
    required this._browser,
  });

  /// Wires the service against the production endpoints in [AppConfig].
  factory AppService.production() {
    final client = ApiClient(baseUri: AppConfig.apiBaseUri);
    final home = HomeDirectory();
    return AppService(
      sessionStore: const SessionStore(),
      authApi: AuthApi(client),
      codexAuthApi: CodexAuthApi(client),
      dashboardApi: DashboardApi(client),
      userPackApi: UserPackApi(client),
      processInspector: const ConflictProcessInspector(),
      rootCertificate: RootCertificateManager(
        home: home,
        assetPath: AppConfig.rootCertificateAssetPath,
      ),
      codexConfig: CodexConfigManager(home: home),
      browser: const ExternalBrowser(),
    );
  }

  final SessionStore _sessionStore;
  final AuthApi _authApi;
  final CodexAuthApi _codexAuthApi;
  final DashboardApi _dashboardApi;
  final UserPackApi _userPackApi;
  final ConflictProcessInspector _processInspector;
  final RootCertificateManager _rootCertificate;
  final CodexConfigManager _codexConfig;
  final ExternalBrowser _browser;

  Future<bool> hasSession() async {
    return await _sessionStore.load() != null;
  }

  Future<void> login({
    required String account,
    required String password,
  }) async {
    final isEmail = account.contains('@');
    final result = await _authApi.login(
      email: isEmail ? account : null,
      phone: isEmail ? null : account,
      password: password,
    );
    await _sessionStore.save(
      SessionState(token: result.token, user: result.user),
    );
  }

  Future<void> logout() => _sessionStore.clear();

  Future<void> openAdminConsole() => _browser.open(AppConfig.adminConsoleUrl);

  Future<void> installRootCertificate() => _rootCertificate.install();

  Future<AppSnapshot> loadSnapshot() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    try {
      final overview = await _dashboardApi.overview(token: session.token);
      final packList = await _userPackApi.listActive(token: session.token);
      final dashboard = DashboardData(
        user: session.user,
        overview: overview,
        packs: packList.packs,
      );

      var localCheckError = '';
      var conflicts = const <ConflictProcess>[];
      try {
        conflicts = await _processInspector.findConflicts();
      } catch (error) {
        localCheckError = error.toString();
      }

      final initialization = await _readInitializationStatusSafely(
        currentError: localCheckError,
        onError: (error) => localCheckError = error,
      );
      final localConfiguration = await _readLocalConfigurationStatus();
      final state = deriveState(
        hasConflicts: conflicts.isNotEmpty,
        certificateInstalled: localConfiguration.rootCertificate.isInstalled,
        hasLocalError: localCheckError.isNotEmpty,
        isInitialized: initialization.isInitialized,
      );

      return AppSnapshot(
        state: state,
        account: AccountSummary.fromDashboard(dashboard),
        initialization: initialization,
        localConfiguration: localConfiguration,
        dashboard: dashboard,
        conflicts: conflicts,
        message: localCheckError.isEmpty ? null : localCheckError,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _sessionStore.clear();
        throw const UnauthenticatedException();
      }
      return AppSnapshot(
        state: RuntimeState.error,
        account: _accountFor(session.user),
        initialization: await _codexConfig.emptyInitializationStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    } catch (error) {
      return AppSnapshot(
        state: RuntimeState.error,
        account: _accountFor(session.user),
        initialization: await _codexConfig.emptyInitializationStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    }
  }

  /// Priority order of the runtime states shown in the dashboard banner.
  @visibleForTesting
  static RuntimeState deriveState({
    required bool hasConflicts,
    required bool certificateInstalled,
    required bool hasLocalError,
    required bool isInitialized,
  }) {
    return hasConflicts
        ? RuntimeState.conflict
        : !certificateInstalled
        ? RuntimeState.rootCertificateMissing
        : hasLocalError
        ? RuntimeState.error
        : isInitialized
        ? RuntimeState.running
        : RuntimeState.uninitialized;
  }

  Future<void> initializeLocalProxyEnv() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    final codexAuth = await _codexAuthApi.createAuth(token: session.token);
    await _codexConfig.initialize(
      codexAuth: codexAuth,
      proxyUrl: AppConfig.proxyUrl,
    );
  }

  /// Restores the user's original Codex configuration from
  /// `~/.codex/old_config`. Throws [CodexConfigRestoreException] when there is
  /// no backup to restore.
  Future<void> restoreOriginalConfig() => _codexConfig.restoreOriginals();

  Future<InitializationStatus> _readInitializationStatusSafely({
    required String currentError,
    required void Function(String error) onError,
  }) async {
    try {
      return await _codexConfig.readInitializationStatus();
    } catch (error) {
      if (currentError.isEmpty) {
        onError(error.toString());
      }
      return _codexConfig.emptyInitializationStatus();
    }
  }

  AccountSummary _accountFor(UserProfile user) {
    return AccountSummary(
      account: user.displayAccount,
      nickname: user.nickname.isEmpty ? '-' : user.nickname,
      balance: '-',
      planName: '-',
      planExpiresAt: '-',
    );
  }

  Future<LocalConfigurationStatus> _readLocalConfigurationStatus() async {
    return LocalConfigurationStatus(
      codexDirectoryPath: await _codexConfig.codexDirectoryPath(),
      claudeDirectoryPath: await _codexConfig.claudeDirectoryPath(),
      isCodexInstalled: await _codexConfig.isCodexInstalled(),
      isClaudeInstalled: await _codexConfig.isClaudeInstalled(),
      canRestoreCodexConfig: await _codexConfig.hasRestorableBackup(),
      rootCertificate: RootCertificateStatus(
        assetPath: _rootCertificate.assetPath,
        isInstalled: await _rootCertificate.isTrusted(),
      ),
    );
  }

  Future<LocalConfigurationStatus> _emptyLocalConfigurationStatus() async {
    return LocalConfigurationStatus(
      codexDirectoryPath: await _codexConfig.codexDirectoryPath(),
      claudeDirectoryPath: await _codexConfig.claudeDirectoryPath(),
      isCodexInstalled: false,
      isClaudeInstalled: false,
      canRestoreCodexConfig: false,
      rootCertificate: RootCertificateStatus(
        assetPath: _rootCertificate.assetPath,
        isInstalled: false,
      ),
    );
  }
}
