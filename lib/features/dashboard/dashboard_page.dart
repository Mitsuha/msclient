import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/app/models/billing_outcome.dart';
import 'package:desktop/features/dashboard/status_alert.dart';
import 'package:desktop/features/dashboard/subscription_summary.dart';
import 'package:desktop/features/dashboard/tool_card.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:desktop/ui/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onApplyCodexBilling,
    required this.onApplyClaudeBilling,
    required this.onInstallRootCertificate,
    this.errorMessage,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final Future<BillingOutcome> Function(int userPackId) onApplyCodexBilling;
  final Future<BillingOutcome> Function(int userPackId) onApplyClaudeBilling;
  final VoidCallback onInstallRootCertificate;

  @override
  Widget build(BuildContext context) {
    final packs = snapshot.dashboard?.packs ?? const [];
    return SingleChildScrollView(
      child: Padding(
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
              onInstallRootCertificate: onInstallRootCertificate,
            ),
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ToolCard(
                      leading: const _ToolBadge(
                        asset: 'assets/images/chatgpt-icon.png',
                      ),
                      title: 'Codex',
                      subtitle: 'OpenAI CLI',
                      status: snapshot.codex,
                      isProxyRunning: snapshot.isProxyRunning,
                      isWorking: isWorking,
                      packs: packs,
                      onApplyBilling: onApplyCodexBilling,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ToolCard(
                      leading: const _ToolBadge(
                        asset: 'assets/images/claude-ai-icon.png',
                      ),
                      title: 'Claude Code',
                      subtitle: 'Anthropic CLI',
                      status: snapshot.claude,
                      isProxyRunning: snapshot.isProxyRunning,
                      isWorking: isWorking,
                      packs: packs,
                      onApplyBilling: onApplyClaudeBilling,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionHeading('订阅'),
            const SizedBox(height: 8),
            SubscriptionSummary(packs: packs),
          ],
        ),
      ),
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
          color: AppColors.neutralButtonBackground,
          textColor: AppColors.label,
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}

/// The vendor logo that brands a tool card.
class _ToolBadge extends StatelessWidget {
  const _ToolBadge({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(asset, width: 48, height: 48, fit: BoxFit.contain);
  }
}
