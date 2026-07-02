import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/local_status.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/models/dashboard_models.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/features/shell/app_shell.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows running control panel state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            AppViewModel(service: _FakeAppService())..bootstrap(),
        child: const CupertinoApp(home: AppShell()),
      ),
    );

    await tester.pump();

    expect(find.text('MirrorStages'), findsOneWidget);
    expect(find.text('正在运行'), findsOneWidget);
    expect(find.text('mirrorstages@example.com'), findsOneWidget);
    expect(find.text('Professional Monthly'), findsOneWidget);
  });
}

class _FakeAppService implements AppService {
  @override
  Future<bool> hasSession() async => true;

  @override
  Future<AppSnapshot> loadSnapshot() async {
    return const AppSnapshot(
      state: RuntimeState.running,
      account: AccountSummary(
        account: 'mirrorstages@example.com',
        nickname: 'MirrorStages User',
        balance: r'$128.00',
        planName: 'Professional Monthly',
        planExpiresAt: '2026-07-30',
      ),
      initialization: InitializationStatus(
        authPath: '/Users/test/.codex/auth.json',
        envPath: '/Users/test/.codex/.env',
        configPath: '/Users/test/.codex/config.toml',
        hasAuthFile: true,
        hasAccessToken: true,
        hasAccountSharingMemberId: true,
        hasHttpProxy: true,
        hasHttpsProxy: true,
        hasCodexProviderOverride: false,
      ),
      localConfiguration: LocalConfigurationStatus(
        codexDirectoryPath: '/Users/test/.codex',
        claudeDirectoryPath: '/Users/test/.claude',
        isCodexInstalled: true,
        isClaudeInstalled: true,
        canRestoreCodexConfig: false,
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
  Future<void> login({required String account, required String password}) {
    throw UnimplementedError();
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
  Future<void> initializeLocalProxyEnv() {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreOriginalConfig() {
    throw UnimplementedError();
  }
}
