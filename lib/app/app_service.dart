import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/api/auth_api.dart';
import 'package:desktop/data/api/claude_auth_api.dart';
import 'package:desktop/data/api/codex_auth_api.dart';
import 'package:desktop/data/api/dashboard_api.dart';
import 'package:desktop/data/api/user_pack_api.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/session/session_store.dart';
import 'package:desktop/system/claude_config_manager.dart';
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
    required this._claudeAuthApi,
    required this._dashboardApi,
    required this._userPackApi,
    required this._processInspector,
    required this._rootCertificate,
    required this._codexConfig,
    required this._claudeConfig,
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
      claudeAuthApi: ClaudeAuthApi(client),
      dashboardApi: DashboardApi(client),
      userPackApi: UserPackApi(client),
      processInspector: const ConflictProcessInspector(),
      rootCertificate: RootCertificateManager(
        home: home,
        assetPath: AppConfig.rootCertificateAssetPath,
      ),
      codexConfig: CodexConfigManager(home: home),
      claudeConfig: ClaudeConfigManager(home: home),
      browser: const ExternalBrowser(),
    );
  }

  final SessionStore _sessionStore;
  final AuthApi _authApi;
  final CodexAuthApi _codexAuthApi;
  final ClaudeAuthApi _claudeAuthApi;
  final DashboardApi _dashboardApi;
  final UserPackApi _userPackApi;
  final ConflictProcessInspector _processInspector;
  final RootCertificateManager _rootCertificate;
  final CodexConfigManager _codexConfig;
  final ClaudeConfigManager _claudeConfig;
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

      final codex = await _codexConfig.readStatus();
      final claude = await _claudeConfig.readStatus();
      final localConfiguration = await _readLocalConfigurationStatus();
      final environment = deriveEnvironment(
        hasConflicts: conflicts.isNotEmpty,
        certificateInstalled: localConfiguration.rootCertificate.isInstalled,
        hasLocalError: localCheckError.isNotEmpty,
      );

      return AppSnapshot(
        environment: environment,
        account: AccountSummary.fromDashboard(dashboard),
        codex: codex,
        claude: claude,
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
        environment: EnvironmentStatus.error,
        account: _accountFor(session.user),
        codex: await _codexConfig.readStatus(),
        claude: await _claudeConfig.readStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    } catch (error) {
      return AppSnapshot(
        environment: EnvironmentStatus.error,
        account: _accountFor(session.user),
        codex: await _codexConfig.readStatus(),
        claude: await _claudeConfig.readStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    }
  }

  /// Priority order of the environment states shown in the dashboard banner.
  @visibleForTesting
  static EnvironmentStatus deriveEnvironment({
    required bool hasConflicts,
    required bool certificateInstalled,
    required bool hasLocalError,
  }) {
    return hasConflicts
        ? EnvironmentStatus.conflict
        : !certificateInstalled
        ? EnvironmentStatus.rootCertificateMissing
        : hasLocalError
        ? EnvironmentStatus.error
        : EnvironmentStatus.ready;
  }

  /// (Re)writes the local Codex credentials billed against [userPackId], where
  /// 0 is pay-as-you-go (按量计费) and any other value is a subscription pack.
  Future<void> initializeLocalProxyEnv({int userPackId = 0}) async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    final codexAuth = await _codexAuthApi.createAuth(
      token: session.token,
      userPackId: userPackId,
    );
    await _codexConfig.initialize(
      codexAuth: codexAuth,
      proxyUrl: AppConfig.proxyUrl,
    );
  }

  /// (Re)writes the local Claude Code credentials billed against [userPackId],
  /// where 0 is pay-as-you-go (按量计费) and any other value is a subscription
  /// pack.
  Future<void> initializeClaude({int userPackId = 0}) async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    final claudeAuth = await _claudeAuthApi.createAuth(
      token: session.token,
      userPackId: userPackId,
    );
    await _claudeConfig.initialize(claudeAuth: claudeAuth);
  }

  /// Restores the user's original Codex configuration from
  /// `~/.codex/old_config`. Throws [CodexConfigRestoreException] when there is
  /// no backup to restore.
  Future<void> restoreOriginalConfig() => _codexConfig.restoreOriginals();

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
      codexDirectoryPath: await _codexConfig.directoryPath(),
      claudeDirectoryPath: await _claudeConfig.directoryPath(),
      isCodexInstalled: await _codexConfig.isInstalled(),
      isClaudeInstalled: await _claudeConfig.isInstalled(),
      canRestoreCodexConfig: await _codexConfig.hasRestorableBackup(),
      rootCertificate: RootCertificateStatus(
        assetPath: _rootCertificate.assetPath,
        isInstalled: await _rootCertificate.isTrusted(),
      ),
    );
  }

  Future<LocalConfigurationStatus> _emptyLocalConfigurationStatus() async {
    return LocalConfigurationStatus(
      codexDirectoryPath: await _codexConfig.directoryPath(),
      claudeDirectoryPath: await _claudeConfig.directoryPath(),
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
