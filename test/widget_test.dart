import 'dart:async';

import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/models/dashboard_models.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/features/shell/app_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/recording_app_logger.dart';

void main() {
  testWidgets('shows running control panel state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppViewModel(
          service: _FakeAppService(),
          logger: RecordingAppLogger(),
        )..bootstrap(),
        child: CupertinoApp(home: AppShell(onExit: () {})),
      ),
    );

    await tester.pump();

    expect(find.text('Mirrorstages'), findsOneWidget);
    expect(find.text('运行环境正常'), findsOneWidget);
    expect(find.text('mirrorstages@example.com'), findsWidgets);
    expect(find.text('Professional Monthly'), findsOneWidget);
  });

  testWidgets('shows starting while sing-box is not connected', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppViewModel(
          service: _FakeAppService(isProxyRunning: false),
          logger: RecordingAppLogger(),
        )..bootstrap(),
        child: CupertinoApp(home: AppShell(onExit: () {})),
      ),
    );

    await tester.pump();

    expect(find.text('启动中'), findsWidgets);
    expect(find.text('运行环境正常'), findsNothing);
  });

  testWidgets('refreshes the snapshot when sing-box startup completes', (
    tester,
  ) async {
    final startup = Completer<void>();
    final service = _FakeAppService(
      isProxyRunning: false,
      proxyStartup: startup,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            AppViewModel(service: service, logger: RecordingAppLogger())
              ..bootstrap(),
        child: CupertinoApp(home: AppShell(onExit: () {})),
      ),
    );
    await tester.pump();
    expect(find.text('启动中'), findsWidgets);

    startup.complete();
    await tester.pumpAndSettle();

    expect(find.text('运行环境正常'), findsOneWidget);
  });

  test('logs unexpected login errors with their stack trace', () async {
    final logger = RecordingAppLogger();
    final service = _FakeAppService(loginError: StateError('network down'));
    final viewModel = AppViewModel(service: service, logger: logger);

    await viewModel.login(account: 'user@example.com', password: 'secret');

    expect(logger.entries, hasLength(1));
    final entry = logger.entries.single;
    expect(entry.event, 'auth.login.failed');
    expect(entry.error, contains('network down'));
    expect(entry.stackTrace, isNotNull);
    expect(entry.context['account'], 'user@example.com');
  });

  test('does not log expected ApiException login errors', () async {
    final logger = RecordingAppLogger();
    final service = _FakeAppService(
      loginError: const ApiException(
        statusCode: 403,
        error: 'api.error.wrong_credentials',
      ),
    );
    final viewModel = AppViewModel(service: service, logger: logger);

    await viewModel.login(account: 'user@example.com', password: 'secret');

    expect(logger.entries, isEmpty);
  });
}

class _FakeAppService implements AppService {
  _FakeAppService({
    this.loginError,
    this.isProxyRunning = true,
    this.proxyStartup,
  });

  final Object? loginError;
  bool isProxyRunning;
  final Completer<void>? proxyStartup;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<AppSnapshot> loadSnapshot() async {
    return AppSnapshot(
      environment: EnvironmentStatus.ready,
      account: AccountSummary(
        account: 'mirrorstages@example.com',
        nickname: 'MirrorStages User',
        balance: r'$128.00',
        planName: 'Professional Monthly',
        planExpiresAt: '2026-07-30',
      ),
      codex: ToolStatus.initialized(
        ToolAccount(
          email: 'codex@example.com',
          planType: 'Plus',
          name: 'Codex User',
        ),
      ),
      claude: ToolStatus.initialized(
        ToolAccount(
          email: 'claude@example.com',
          name: 'claude',
          planType: 'Max 20X',
        ),
      ),
      isProxyRunning: isProxyRunning,
      localConfiguration: LocalConfigurationStatus(
        codexDirectoryPath: '/Users/test/.codex',
        claudeDirectoryPath: '/Users/test/.claude',
        isCodexInstalled: true,
        isClaudeInstalled: true,
        canRestoreCodexConfig: false,
        canRestoreClaudeConfig: false,
        rootCertificate: RootCertificateStatus(
          assetPath: 'assets/ca/mirrorstages-root-ca.cer',
          isInstalled: true,
        ),
      ),
      dashboard: DashboardData(
        user: UserProfile(
          id: 1001,
          phone: '',
          email: 'mirrorstages@example.com',
          nickname: 'MirrorStages User',
          priceRatio: 1,
          inviteCode: '',
          alipayAccount: '',
          alipayName: '',
          createdAt: null,
          updatedAt: null,
        ),
        overview: DashboardOverview(
          balance: 128,
          tokenUsage: 0,
          tokenUsageUpdatedAt: null,
          apiKeyCount: 0,
        ),
        packs: [
          UserPack(
            id: 501,
            product: UserPackProduct(
              id: 12,
              name: 'Professional Monthly',
              balance: 100,
              grouping: 'claude_coding',
            ),
            remainAmount: 72,
            status: UserPackStatus.active,
            apiKeyCount: 0,
            lastUsedAt: null,
            startAt: null,
            expireAt: null,
            createdAt: null,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> login({
    required String account,
    required String password,
  }) async {
    if (loginError case final error?) {
      throw error;
    }
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> openAdminConsole() {
    throw UnimplementedError();
  }

  @override
  Future<void> installRootCertificate() {
    throw UnimplementedError();
  }

  @override
  Future<void> initializeLocalProxyEnv({int userPackId = 0}) {
    throw UnimplementedError();
  }

  @override
  Future<void> initializeClaude({int userPackId = 0}) {
    throw UnimplementedError();
  }

  @override
  Future<void> selectProxy(String url) async {}

  @override
  Future<void> clearProxyConfig() {
    throw UnimplementedError();
  }

  @override
  Future<void> stripToolProxyConfig() async {}

  @override
  Future<void> reapplyIssuedProxyConfig() async {}

  @override
  Future<void> startProxy() async {
    final startup = proxyStartup;
    if (startup != null) {
      await startup.future;
      isProxyRunning = true;
    }
  }

  @override
  Future<void> stopProxy() async {}

  @override
  Future<void> applyCodexInitStep(String stepId) {
    throw UnimplementedError();
  }

  @override
  Future<void> applyClaudeInitStep(String stepId) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreOriginalConfig() {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreClaudeConfig() {
    throw UnimplementedError();
  }
}
