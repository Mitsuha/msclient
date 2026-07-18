import 'dart:async';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/app_exceptions.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/app/proxy_service.dart';
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
import 'package:desktop/data/preferences/proxy_preference_store.dart';
import 'package:desktop/data/session/session_store.dart';
import 'package:desktop/domain/tools/claude_tool.dart';
import 'package:desktop/domain/tools/codex_tool.dart';
import 'package:desktop/domain/tools/tool.dart';
import 'package:desktop/domain/tools/tool_initializer.dart';
import 'package:desktop/system/claude_config_manager.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:desktop/system/external_browser.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/process_inspector.dart';
import 'package:desktop/system/root_certificate_manager.dart';
import 'package:desktop/system/singbox_binary.dart';
import 'package:desktop/system/singbox_process.dart';
import 'package:flutter/foundation.dart';

/// Facade the view model talks to: orchestrates the remote APIs (data/), the
/// local proxy ([ProxyService]), and the local tools ([Tool]) into snapshots
/// and actions.
///
/// The two supported tools (Codex, Claude Code) are held uniformly in [_tools]
/// and driven by looping — no method is duplicated per tool. Snapshot assembly
/// keeps the tools' results in maps and maps them onto [AppSnapshot]'s named
/// codex/claude fields, so the UI contract is unchanged.
class AppService {
  AppService({
    required this._sessionStore,
    required this._authApi,
    required this._dashboardApi,
    required this._userPackApi,
    required this._processInspector,
    required this._rootCertificate,
    required this._browser,
    required this._proxy,
    required this._tools,
  });

  /// Wires the service against the production endpoints in [AppConfig].
  factory AppService.production({required AppLogger logger}) {
    final client = ApiClient(baseUri: AppConfig.apiBaseUri);
    final home = HomeDirectory();
    const sessionStore = SessionStore();

    Future<String> requireToken() async {
      final session = await sessionStore.load();
      if (session == null) {
        throw const UnauthenticatedException();
      }
      return session.token;
    }

    Future<String> resolveProxyUrl() async => AppConfig.singboxLocalProxyUrl;

    final tools = <ToolId, Tool>{
      ToolId.codex: CodexTool(
        config: CodexConfigManager(home: home),
        authApi: ToolAuthApi.codex(client),
        resolveProxyUrl: resolveProxyUrl,
        requireToken: requireToken,
      ),
      ToolId.claude: ClaudeTool(
        config: ClaudeConfigManager(home: home),
        authApi: ToolAuthApi.claude(client),
        resolveProxyUrl: resolveProxyUrl,
        requireToken: requireToken,
      ),
    };

    return AppService(
      sessionStore: sessionStore,
      authApi: AuthApi(client),
      dashboardApi: DashboardApi(client),
      userPackApi: UserPackApi(client),
      processInspector: const ConflictProcessInspector(),
      rootCertificate: RootCertificateManager(
        home: home,
        assetPath: AppConfig.rootCertificateAssetPath,
      ),
      browser: const ExternalBrowser(),
      proxy: ProxyService(
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
        configApi: DesktopConfigApi(client),
        preferences: const ProxyPreferenceStore(),
      ),
      tools: tools,
    );
  }

  final SessionStore _sessionStore;
  final AuthApi _authApi;
  final DashboardApi _dashboardApi;
  final UserPackApi _userPackApi;
  final ConflictProcessInspector _processInspector;
  final RootCertificateManager _rootCertificate;
  final ExternalBrowser _browser;
  final ProxyService _proxy;
  final Map<ToolId, Tool> _tools;

  Iterable<Tool> get _toolList => _tools.values;
  Tool _tool(ToolId id) => _tools[id]!;

  // --- Proxy lifecycle ---

  /// Launches the local proxy in the background. Best-effort; never throws.
  Future<void> startProxy() => _proxy.start();

  /// Stops the local proxy. Call on app shutdown.
  Future<void> stopProxy() => _proxy.stop();

  // --- Session ---

  Future<bool> hasSession() async => await _sessionStore.load() != null;

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

  // --- Tool lifecycle (uniform across every tool) ---

  /// Runs the full initialization for [id] billed against [userPackId] (0 =
  /// pay-as-you-go / 按量计费). Backs up the user's originals only on a genuine
  /// first-time initialization.
  Future<void> initializeTool(ToolId id, {int userPackId = 0}) =>
      _tool(id).initialize(userPackId: userPackId);

  /// Re-applies a single initialization step for [id], keeping the billing pack
  /// the current credentials are on.
  Future<void> applyToolInitStep(ToolId id, String stepId) =>
      _tool(id).applyStep(stepId);

  /// Restores the user's original config for [id]. Throws when there is no
  /// backup to restore.
  Future<void> restoreToolConfig(ToolId id) => _tool(id).restoreOriginals();

  /// Clears the MirrorStages proxy configuration from every tool's config,
  /// preserving every other setting.
  Future<void> clearProxyConfig() async {
    for (final tool in _toolList) {
      await tool.clearProxy();
    }
  }

  /// Strips the local proxy from every tool's config on app quit, preserving
  /// every other setting. Best-effort per tool so one failure never blocks the
  /// others or the quit sequence. Called before the proxy is stopped so the
  /// tools stop pointing at a dead local address.
  Future<void> stripToolProxyConfig() async {
    for (final tool in _toolList) {
      try {
        await tool.stripProxy();
      } catch (_) {}
    }
  }

  /// Re-pins the local proxy for any tool whose on-disk credentials are still a
  /// MirrorStages-issued account, silently. Run once on a genuine launch to
  /// restore the proxy config stripped on the previous quit. Best-effort per
  /// tool.
  Future<void> reapplyIssuedProxyConfig() async {
    for (final tool in _toolList) {
      try {
        if (await tool.hasIssuedCredentials()) {
          await tool.writeProxy(_proxy.localProxyUrl);
        }
      } catch (_) {}
    }
  }

  /// Persists the picked node and switches sing-box's selector to it. Tools keep
  /// pointing at the constant local proxy; their configs are re-pinned to it
  /// only to migrate any that still carry an old remote address.
  Future<void> selectProxy(String url) async {
    await _proxy.select(url);
    for (final tool in _toolList) {
      if ((await tool.readStatus()).isInitialized) {
        await tool.writeProxy(_proxy.localProxyUrl);
      }
    }
  }

  // --- Snapshot assembly ---

  Future<AppSnapshot> loadSnapshot() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    // Keep sing-box aligned with the current node list/selection, then gate the
    // tool cards' "正在运行" on it actually being up.
    final proxyState = await _proxy.reconcile();
    final proxyRunning = await _proxy.isHealthy();

    // Local reads are the same whether or not the remote dashboard loads.
    final tools = await _readToolSnapshot();
    final localConfiguration = await _readLocalConfigurationStatus(
      tools.installs,
    );

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

      final environment = deriveEnvironment(
        hasConflicts: conflicts.isNotEmpty,
        certificateInstalled: localConfiguration.rootCertificate.isInstalled,
        hasLocalError: localCheckError.isNotEmpty,
      );

      return AppSnapshot(
        environment: environment,
        account: AccountSummary.fromDashboard(dashboard),
        codex: tools.statuses[ToolId.codex]!,
        claude: tools.statuses[ToolId.claude]!,
        localConfiguration: localConfiguration,
        dashboard: dashboard,
        conflicts: conflicts,
        proxyOptions: proxyState.options,
        selectedProxyUrl: proxyState.selectedUrl,
        codexInitSteps: tools.steps[ToolId.codex]!,
        claudeInitSteps: tools.steps[ToolId.claude]!,
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
        tools: tools,
        localConfiguration: localConfiguration,
        proxyState: proxyState,
        isProxyRunning: proxyRunning,
        message: error.toString(),
      );
    } catch (error) {
      return _errorSnapshot(
        user: session.user,
        tools: tools,
        localConfiguration: localConfiguration,
        proxyState: proxyState,
        isProxyRunning: proxyRunning,
        message: error.toString(),
      );
    }
  }

  /// The degraded snapshot shown when loading the remote dashboard fails: the
  /// local tool state is still real, the remote-derived fields are blank.
  AppSnapshot _errorSnapshot({
    required UserProfile user,
    required _ToolSnapshot tools,
    required LocalConfigurationStatus localConfiguration,
    required ProxyState proxyState,
    required bool isProxyRunning,
    required String message,
  }) {
    return AppSnapshot(
      environment: EnvironmentStatus.error,
      account: _accountFor(user),
      codex: tools.statuses[ToolId.codex]!,
      claude: tools.statuses[ToolId.claude]!,
      localConfiguration: localConfiguration,
      proxyOptions: proxyState.options,
      selectedProxyUrl: proxyState.selectedUrl,
      codexInitSteps: tools.steps[ToolId.codex]!,
      claudeInitSteps: tools.steps[ToolId.claude]!,
      isProxyRunning: isProxyRunning,
      message: message,
    );
  }

  /// Reads every tool's account status, init steps, and install info in one
  /// pass so both the healthy and degraded snapshots share the same source.
  Future<_ToolSnapshot> _readToolSnapshot() async {
    final statuses = <ToolId, ToolStatus>{};
    final steps = <ToolId, List<InitStepStatus>>{};
    final installs = <ToolId, ToolInstallInfo>{};
    for (final tool in _toolList) {
      statuses[tool.id] = await tool.readStatus();
      steps[tool.id] = await tool.checkSteps();
      installs[tool.id] = await tool.readInstallInfo();
    }
    return _ToolSnapshot(statuses: statuses, steps: steps, installs: installs);
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

  AccountSummary _accountFor(UserProfile user) {
    return AccountSummary(
      account: user.displayAccount,
      nickname: user.nickname.isEmpty ? '-' : user.nickname,
      balance: '-',
      planName: '-',
      planExpiresAt: '-',
    );
  }

  Future<LocalConfigurationStatus> _readLocalConfigurationStatus(
    Map<ToolId, ToolInstallInfo> installs,
  ) async {
    final codex = installs[ToolId.codex]!;
    final claude = installs[ToolId.claude]!;
    return LocalConfigurationStatus(
      codexDirectoryPath: codex.directoryPath,
      claudeDirectoryPath: claude.directoryPath,
      isCodexInstalled: codex.isInstalled,
      isClaudeInstalled: claude.isInstalled,
      canRestoreCodexConfig: codex.canRestoreConfig,
      canRestoreClaudeConfig: claude.canRestoreConfig,
      rootCertificate: RootCertificateStatus(
        assetPath: _rootCertificate.assetPath,
        isInstalled: await _rootCertificate.isTrusted(),
      ),
    );
  }
}

/// The per-tool local reads gathered once for a snapshot.
class _ToolSnapshot {
  const _ToolSnapshot({
    required this.statuses,
    required this.steps,
    required this.installs,
  });

  final Map<ToolId, ToolStatus> statuses;
  final Map<ToolId, List<InitStepStatus>> steps;
  final Map<ToolId, ToolInstallInfo> installs;
}
