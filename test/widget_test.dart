import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:desktop/features/control_panel/control_panel_models.dart';
import 'package:desktop/features/control_panel/control_panel_screen.dart';
import 'package:desktop/features/control_panel/control_panel_service.dart';
import 'package:desktop/features/control_panel/control_panel_view_model.dart';

void main() {
  testWidgets('shows running control panel state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            ControlPanelViewModel(service: const _FakeControlPanelService())
              ..load(),
        child: const CupertinoApp(home: ControlPanelScreen()),
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
  const _FakeControlPanelService();

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
        hasAuthFile: true,
        hasAccessToken: true,
        hasAccountSharingMemberId: true,
        hasHttpProxy: true,
        hasHttpsProxy: true,
      ),
    );
  }
}
