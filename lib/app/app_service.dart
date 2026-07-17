import 'dart:async';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/initialization/claude_initializer.dart';
import 'package:desktop/app/initialization/codex_initializer.dart';
import 'package:desktop/app/initialization/tool_initializer.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/app/singbox/singbox_config_builder.dart';
import 'package:desktop/app/singbox/singbox_controller.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/data/api/auth_api.dart';
import 'package:desktop/data/api/dashboard_api.dart';
import 'package:desktop/data/api/desktop_config_api.dart';
import 'package:desktop/data/api/singbox_clash_api.dart';
import 'package:desktop/data/api/tool_auth_api.dart';
import 'package:desktop/data/api/user_pack_api.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:desktop/data/preferences/proxy_preference_store.dart';
import 'package:desktop/data/session/session_store.dart';
import 'package:desktop/system/claude_config_manager.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:desktop/system/external_browser.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/process_inspector.dart';
import 'package:desktop/system/root_certificate_manager.dart';
import 'package:desktop/system/singbox_binary.dart';
import 'package:desktop/system/singbox_process.dart';
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
    required this._desktopConfigApi,
    required this._proxyPreferences,
    required this._processInspector,
    required this._rootCertificate,
    required this._codexConfig,
    required this._claudeConfig,
    required this._browser,
    required this._singbox,
  });

  /// Wires the service against the production endpoints in [AppConfig].
  factory AppService.production({required AppLogger logger}) {
    final client = ApiClient(baseUri: AppConfig.apiBaseUri);
    final home = HomeDirectory();
    return AppService(
      sessionStore: const SessionStore(),
      authApi: AuthApi(client),
      codexAuthApi: ToolAuthApi.codex(client),
      claudeAuthApi: ToolAuthApi.claude(client),
      dashboardApi: DashboardApi(client),
      userPackApi: UserPackApi(client),
      desktopConfigApi: DesktopConfigApi(client),
      proxyPreferences: const ProxyPreferenceStore(),
      processInspector: const ConflictProcessInspector(),
      rootCertificate: RootCertificateManager(
        home: home,
        assetPath: AppConfig.rootCertificateAssetPath,
      ),
      codexConfig: CodexConfigManager(home: home),
      claudeConfig: ClaudeConfigManager(home: home),
      browser: const ExternalBrowser(),
      singbox: SingboxController(
        binary: SingboxBinary(home: home, logger: logger),
        process: SingboxProcess(),
        api: SingboxClashApiClient(
          baseUri: AppConfig.singboxClashApiBaseUri,
          secret: AppConfig.singboxClashSecret,
        ),
        builder: const SingboxConfigBuilder(),
        home: home,
        logger: logger,
      ),
    );
  }

  final SessionStore _sessionStore;
  final AuthApi _authApi;
  final ToolAuthApi _codexAuthApi;
  final ToolAuthApi _claudeAuthApi;
  final DashboardApi _dashboardApi;
  final UserPackApi _userPackApi;
  final DesktopConfigApi _desktopConfigApi;
  final ProxyPreferenceStore _proxyPreferences;
  final ConflictProcessInspector _processInspector;
  final RootCertificateManager _rootCertificate;
  final CodexConfigManager _codexConfig;
  final ClaudeConfigManager _claudeConfig;
  final ExternalBrowser _browser;
  final SingboxController _singbox;

  /// The most recent node list fetched from the server, so [selectProxy] can
  /// rebuild the config against the full set of outbounds.
  List<ClientProxyOption> _lastProxyOptions = const [];

  /// Launches sing-box with an outbound per node and the selected node active.
  /// Best-effort: never throws, so a failure (e.g. offline first run) can't
  /// block the app.
  Future<void> startProxy() async {
    try {
      final options = await _loadProxyOptions();
      final selected = await _selectedProxyUrlFor(options);
      await _singbox.apply(_proxiesOrFallback(options), selectedUrl: selected);
    } catch (error) {
      debugPrint('startProxy failed: $error');
    }
  }

  /// Stops the local sing-box process. Call on app shutdown.
  Future<void> stopProxy() => _singbox.stop();

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

    final proxyOptions = await _loadProxyOptions();
    final selectedProxyUrl = await _selectedProxyUrlFor(proxyOptions);

    // Keep sing-box aligned with the current node list/selection; restarts when
    // the outbound set changed, flips the selector when only the choice did,
    // no-ops when unchanged. Best-effort: nobody awaits this, so a dead sing-box
    // must not become an unhandled zone exception.
    unawaited(
      _singbox
          .apply(
            _proxiesOrFallback(proxyOptions),
            selectedUrl: selectedProxyUrl,
          )
          .catchError(
            (Object error) => debugPrint('singbox.apply failed: $error'),
          ),
    );

    // Gate the tool cards' "正在运行" on sing-box actually being up.
    final proxyRunning = await _singbox.isHealthy();

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
      final codexInitSteps = await _codexInitializer().checkSteps();
      final claudeInitSteps = await _claudeInitializer().checkSteps();
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
        proxyOptions: proxyOptions,
        selectedProxyUrl: selectedProxyUrl,
        codexInitSteps: codexInitSteps,
        claudeInitSteps: claudeInitSteps,
        isProxyRunning: proxyRunning,
        message: localCheckError.isEmpty ? null : localCheckError,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _sessionStore.clear();
        throw const UnauthenticatedException();
      }
      return _errorSnapshot(
        user: session.user,
        proxyOptions: proxyOptions,
        selectedProxyUrl: selectedProxyUrl,
        isProxyRunning: proxyRunning,
        message: error.toString(),
      );
    } catch (error) {
      return _errorSnapshot(
        user: session.user,
        proxyOptions: proxyOptions,
        selectedProxyUrl: selectedProxyUrl,
        isProxyRunning: proxyRunning,
        message: error.toString(),
      );
    }
  }

  /// The degraded snapshot shown when loading the remote dashboard fails: the
  /// local tool state is still read live, the remote-derived fields are blank.
  Future<AppSnapshot> _errorSnapshot({
    required UserProfile user,
    required List<ClientProxyOption> proxyOptions,
    required String? selectedProxyUrl,
    required bool isProxyRunning,
    required String message,
  }) async {
    return AppSnapshot(
      environment: EnvironmentStatus.error,
      account: _accountFor(user),
      codex: await _codexConfig.readStatus(),
      claude: await _claudeConfig.readStatus(),
      localConfiguration: await _emptyLocalConfigurationStatus(),
      proxyOptions: proxyOptions,
      selectedProxyUrl: selectedProxyUrl,
      codexInitSteps: await _codexInitializer().checkSteps(),
      claudeInitSteps: await _claudeInitializer().checkSteps(),
      isProxyRunning: isProxyRunning,
      message: message,
    );
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

  /// The Codex initialization steps; [userPackId] (0 = pay-as-you-go /
  /// 按量计费) is baked into the auth-fetching closure and only matters when a
  /// step is applied.
  ToolInitializer _codexInitializer({int userPackId = 0}) => codexInitializer(
    config: _codexConfig,
    resolveProxyUrl: _resolveLocalProxyUrl,
    fetchAuth: () async => _codexAuthApi.createAuth(
      token: await _requireToken(),
      userPackId: userPackId,
    ),
  );

  /// The Claude Code initialization steps; see [_codexInitializer].
  ToolInitializer _claudeInitializer({int userPackId = 0}) => claudeInitializer(
    config: _claudeConfig,
    resolveProxyUrl: _resolveLocalProxyUrl,
    fetchAuth: () async => _claudeAuthApi.createAuth(
      token: await _requireToken(),
      userPackId: userPackId,
    ),
  );

  /// Runs the full Codex initialization billed against [userPackId], where 0
  /// is pay-as-you-go (按量计费) and any other value is a subscription pack.
  ///
  /// The original config is backed up into `old_config` only on a genuine
  /// first-time initialization (Codex not yet initialized). Re-running this to
  /// change billing leaves the existing backup untouched and creates none.
  Future<void> initializeLocalProxyEnv({int userPackId = 0}) async {
    final firstTime = !(await _codexConfig.readStatus()).isInitialized;
    await _codexInitializer(
      userPackId: userPackId,
    ).initialize(backupOriginals: firstTime);
  }

  /// Runs the full Claude Code initialization billed against [userPackId],
  /// where 0 is pay-as-you-go (按量计费) and any other value is a subscription
  /// pack.
  ///
  /// Backs up into `old_config` only on a genuine first-time initialization;
  /// see [initializeLocalProxyEnv].
  Future<void> initializeClaude({int userPackId = 0}) async {
    final firstTime = !(await _claudeConfig.readStatus()).isInitialized;
    await _claudeInitializer(
      userPackId: userPackId,
    ).initialize(backupOriginals: firstTime);
  }

  /// Re-applies a single Codex initialization step, keeping the billing pack
  /// the current credentials are on.
  Future<void> applyCodexInitStep(String stepId) async {
    final userPackId = (await _codexConfig.readStatus()).account?.userPackId;
    await _codexInitializer(userPackId: userPackId ?? 0).applyStep(stepId);
  }

  /// Re-applies a single Claude Code initialization step, keeping the billing
  /// pack the current credentials are on.
  Future<void> applyClaudeInitStep(String stepId) async {
    final userPackId = (await _claudeConfig.readStatus()).account?.userPackId;
    await _claudeInitializer(userPackId: userPackId ?? 0).applyStep(stepId);
  }

  /// Persists the picked node and switches sing-box's selector to it. Tools keep
  /// pointing at the constant local proxy; their configs are re-pinned to it
  /// only to migrate any that still carry an old remote address.
  Future<void> selectProxy(String url) async {
    await _proxyPreferences.save(url);
    await _singbox.apply(
      _proxiesOrFallback(_lastProxyOptions),
      selectedUrl: url,
    );
    if ((await _codexConfig.readStatus()).isInitialized) {
      await _codexConfig.writeProxyEnv(AppConfig.singboxLocalProxyUrl);
    }
    if ((await _claudeConfig.readStatus()).isInitialized) {
      await _claudeConfig.writeProxySettings(AppConfig.singboxLocalProxyUrl);
    }
  }

  Future<String> _requireToken() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }
    return session.token;
  }

  Future<List<ClientProxyOption>> _loadProxyOptions() async {
    try {
      final options = await _desktopConfigApi.clientProxies();
      _lastProxyOptions = options;
      return options;
    } catch (_) {
      return const [];
    }
  }

  /// Guarantees a non-empty node list so the config always has at least one
  /// outbound: the built-in [AppConfig.proxyUrl] stands in when the server list
  /// is empty/unavailable.
  List<ClientProxyOption> _proxiesOrFallback(List<ClientProxyOption> options) =>
      options.isEmpty
      ? const [ClientProxyOption(name: 'default', url: AppConfig.proxyUrl)]
      : options;

  /// The saved choice wins while it is still offered by the server; otherwise
  /// the server-sorted first option is the default.
  Future<String?> _selectedProxyUrlFor(List<ClientProxyOption> options) async {
    final saved = await _proxyPreferences.load();
    if (saved != null && options.any((option) => option.url == saved)) {
      return saved;
    }
    return options.isEmpty ? null : options.first.url;
  }

  /// The constant local sing-box proxy written into every tool's config.
  Future<String> _resolveLocalProxyUrl() async =>
      AppConfig.singboxLocalProxyUrl;

  /// Clears the MirrorStages proxy configuration written into the local tools:
  /// removes the proxy entries from Claude Code's `settings.json` and deletes
  /// Codex's `.env`. Every other setting is left untouched.
  Future<void> clearProxyConfig() async {
    await _claudeConfig.clearProxySettings();
    await _codexConfig.clearProxyEnv();
  }

  /// Strips the local sing-box proxy from both tools' configs on app quit,
  /// preserving every other setting (Claude `settings.json` keeps its other
  /// entries; Codex `.env` keeps any non-proxy entries). Best-effort per tool
  /// so one failure never blocks the other or the quit sequence. Called before
  /// the proxy is stopped so the tools stop pointing at a dead local address.
  Future<void> stripToolProxyConfig() async {
    try {
      await _claudeConfig.clearProxySettings();
    } catch (_) {}
    try {
      await _codexConfig.removeProxyEnv();
    } catch (_) {}
  }

  /// Re-pins the local proxy for any tool whose on-disk credentials are still a
  /// MirrorStages-issued (parseable) account, silently and without prompting.
  /// Run once on a genuine launch to restore the proxy config stripped on the
  /// previous quit. Best-effort per tool. Uses the auth-only predicates so it
  /// still recognizes our account even though the proxy config is currently
  /// absent (unlike `readStatus().isInitialized`, which requires the proxy).
  Future<void> reapplyIssuedProxyConfig() async {
    try {
      if (await _codexConfig.hasMirrorStagesAuth()) {
        await _codexConfig.writeProxyEnv(AppConfig.singboxLocalProxyUrl);
      }
    } catch (_) {}
    try {
      if (await _claudeConfig.hasMirrorStagesCredentials()) {
        await _claudeConfig.writeProxySettings(AppConfig.singboxLocalProxyUrl);
      }
    } catch (_) {}
  }

  /// Restores the user's original Codex configuration from
  /// `~/.codex/old_config`. Throws [CodexConfigRestoreException] when there is
  /// no backup to restore.
  Future<void> restoreOriginalConfig() => _codexConfig.restoreOriginals();

  /// Restores the user's original Claude Code configuration from
  /// `~/.claude/old_config`. Throws [ClaudeConfigRestoreException] when there
  /// is no backup to restore.
  Future<void> restoreClaudeConfig() => _claudeConfig.restoreOriginals();

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
      canRestoreClaudeConfig: await _claudeConfig.hasRestorableBackup(),
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
      canRestoreClaudeConfig: false,
      rootCertificate: RootCertificateStatus(
        assetPath: _rootCertificate.assetPath,
        isInstalled: false,
      ),
    );
  }
}
