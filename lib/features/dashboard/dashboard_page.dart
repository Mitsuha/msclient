import 'package:desktop/app/models/app_snapshot.dart';
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
  final Future<bool> Function(int userPackId) onApplyCodexBilling;
  final Future<bool> Function(int userPackId) onApplyClaudeBilling;
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
                      leading: const _CodexBadge(),
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
                      leading: const _ClaudeBadge(),
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
            SectionCard(
              title: '订阅',
              child: SubscriptionSummary(packs: packs),
            ),
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

/// The dark terminal tile that brands the Codex card.
class _CodexBadge extends StatelessWidget {
  const _CodexBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.label,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        '>_',
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// The coral sparkles tile that brands the Claude Code card.
class _ClaudeBadge extends StatelessWidget {
  const _ClaudeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.claudeBrand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        CupertinoIcons.sparkles,
        color: CupertinoColors.white,
        size: 24,
      ),
    );
  }
}
