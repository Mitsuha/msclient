import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/core/session/session_store.dart';
import 'package:desktop/features/models/account_models.dart';
import 'package:desktop/features/api/auth_api.dart';
import 'package:desktop/features/api/codex_auth_api.dart';
import 'package:desktop/features/models/control_panel_models.dart';
import 'package:desktop/features/pages/control_panel_page.dart';
import 'package:desktop/features/services/control_panel_service.dart';
import 'package:desktop/features/view_models/control_panel_view_model.dart';
import 'package:desktop/features/api/dashboard_api.dart';
import 'package:desktop/features/models/dashboard_models.dart';
import 'package:desktop/features/models/pack_models.dart';
import 'package:desktop/features/api/user_pack_api.dart';

void main() {
  testWidgets('shows running control panel state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            ControlPanelViewModel(service: _FakeControlPanelService())
              ..bootstrap(),
        child: const CupertinoApp(home: ControlPanelPage()),
      ),
    );

    await tester.pump();

    expect(find.text('MirrorStages'), findsOneWidget);
    expect(find.text('正在运行'), findsOneWidget);
    expect(find.text('mirrorstages@example.com'), findsOneWidget);
    expect(find.text('Professional Monthly'), findsOneWidget);
  });
}

class _FakeControlPanelService extends ControlPanelService {
  _FakeControlPanelService()
    : super(
        sessionStore: const SessionStore(),
        authApi: AuthApi(_client),
        codexAuthApi: CodexAuthApi(_client),
        dashboardApi: DashboardApi(_client),
        userPackApi: UserPackApi(_client),
      );

  static final _client = ApiClient(
    baseUri: Uri.parse('http://127.0.0.1:8080/api'),
  );

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<ControlPanelSnapshot> loadSnapshot() async {
    return const ControlPanelSnapshot(
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
}
