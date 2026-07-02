import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/features/dashboard/account_table.dart';
import 'package:desktop/features/dashboard/status_alert.dart';
import 'package:desktop/features/dashboard/subscription_summary.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:desktop/ui/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInitialize,
    required this.onInstallRootCertificate,
    this.errorMessage,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onInstallRootCertificate;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(isWorking: isWorking, onRefresh: onRefresh),
          const SizedBox(height: 18),
          StatusAlert(
            snapshot: snapshot,
            isWorking: isWorking,
            errorMessage: errorMessage,
            onRefresh: onRefresh,
            onInitialize: onInitialize,
            onInstallRootCertificate: onInstallRootCertificate,
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '账户',
            child: AccountTable(account: snapshot.account),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '订阅',
            child: SubscriptionSummary(
              packs: snapshot.dashboard?.packs ?? const [],
            ),
          ),
          const Spacer(),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 520) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.isWorking, required this.onRefresh});

  final bool isWorking;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '控制面板',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        if (isWorking) ...[
          const CupertinoActivityIndicator(radius: 9),
          const SizedBox(width: 10),
        ],
        AppButton(
          icon: CupertinoIcons.arrow_clockwise,
          label: '刷新',
          compact: true,
          color: const Color(0xFFE9E9ED),
          textColor: const Color(0xFF1D1D1F),
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}
