import 'dart:async';

import 'package:desktop/app/models/billing_outcome.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/features/dashboard/billing_dialog.dart';
import 'package:desktop/features/dashboard/no_available_account_dialog.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// Dashboard card for a local AI CLI tool's configuration (Codex, Claude Code).
///
/// Always surfaces the account fields (empty until initialized). The header
/// pill reflects three states: `未初始化` before setup, `正在运行` once the tool is
/// initialized *and* the local sing-box proxy it routes through is up, or
/// `代理未运行` when it is initialized but that proxy is down. The bottom action
/// is `更换计费` when initialized, or `初始化` when not — both open the billing
/// picker and apply the chosen method via [onApplyBilling].
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isProxyRunning,
    required this.isWorking,
    required this.packs,
    required this.onApplyBilling,
  });

  /// The 48x48 brand icon tile shown at the start of the header.
  final Widget leading;
  final String title;
  final String subtitle;
  final ToolStatus status;

  /// Whether the local sing-box proxy is up. An initialized tool only counts as
  /// "正在运行" while this holds, since every request routes through that proxy.
  final bool isProxyRunning;

  final bool isWorking;

  /// The subscriptions offered in the billing picker.
  final List<UserPack> packs;

  /// Applies the chosen billing method: 0 for pay-as-you-go (按量计费) or a
  /// subscription pack id. The [BillingOutcome] drives the follow-up UI:
  /// [BillingOutcome.success] shows the "restart to take effect" hint, while
  /// [BillingOutcome.noAvailableAccount] pops the empty-pool dialog.
  final Future<BillingOutcome> Function(int userPackId) onApplyBilling;

  @override
  Widget build(BuildContext context) {
    final account = status.account;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            leading: leading,
            title: title,
            subtitle: subtitle,
            pill: account == null
                ? _PillState.idle
                : isProxyRunning
                ? _PillState.running
                : _PillState.proxyDown,
          ),
          const _Divider(),
          _Body(
            toolName: title,
            account: account,
            isWorking: isWorking,
            packs: packs,
            onApplyBilling: onApplyBilling,
          ),
        ],
      ),
    );
  }
}

/// The header pill's three states: not yet set up, running through a healthy
/// proxy, or set up but the local proxy is down.
enum _PillState { idle, running, proxyDown }

class _Header extends StatelessWidget {
  const _Header({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.pill,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final _PillState pill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(state: pill),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _PillState state;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (state) {
      _PillState.running => (
        '正在运行',
        AppColors.successText,
        AppColors.successBackground,
      ),
      _PillState.proxyDown => (
        '代理未运行',
        AppColors.dangerText,
        AppColors.dangerBackground,
      ),
      _PillState.idle => (
        '未初始化',
        AppColors.tertiaryLabel,
        AppColors.mutedBackground,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.toolName,
    required this.account,
    required this.isWorking,
    required this.packs,
    required this.onApplyBilling,
  });

  final String toolName;
  final ToolAccount? account;
  final bool isWorking;
  final List<UserPack> packs;
  final Future<BillingOutcome> Function(int userPackId) onApplyBilling;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// True while the chosen billing method is being written to disk.
  bool _isApplying = false;

  /// True for the few seconds after a successful apply, while the button shows
  /// the "restart to take effect" hint.
  bool _showRestartHint = false;

  Timer? _restartHintTimer;

  @override
  void dispose() {
    _restartHintTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickBilling() async {
    final selected = await showBillingDialog(
      context,
      toolName: widget.toolName,
      currentUserPackId: widget.account?.userPackId ?? 0,
      packs: widget.packs,
    );
    if (selected == null || !mounted) {
      return;
    }

    _restartHintTimer?.cancel();
    setState(() {
      _isApplying = true;
      _showRestartHint = false;
    });

    final outcome = await widget.onApplyBilling(selected);
    if (!mounted) {
      return;
    }

    final succeeded = outcome == BillingOutcome.success;
    setState(() {
      _isApplying = false;
      _showRestartHint = succeeded;
    });

    if (succeeded) {
      _restartHintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showRestartHint = false);
        }
      });
    } else if (outcome == BillingOutcome.noAvailableAccount) {
      await showNoAvailableAccountDialog(context, toolName: widget.toolName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final isInitialized = account != null;
    // The whole card is busy while any billing operation runs; only this card
    // shows the spinner, but both cards disable while the shared work is live.
    final disabled = widget.isWorking || _isApplying;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: '邮箱', child: _ValueText(account?.email)),
          const SizedBox(height: 15),
          _InfoRow(label: '用户名', child: _ValueText(account?.name)),
          const SizedBox(height: 15),
          _InfoRow(
            label: '套餐类型',
            child: account == null || account.planType.isEmpty
                ? const _ValueText(null)
                : _PlanBadge(planType: account.planType),
          ),
          const SizedBox(height: 18),
          _buildActionButton(isInitialized: isInitialized, disabled: disabled),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required bool isInitialized,
    required bool disabled,
  }) {
    if (_showRestartHint) {
      // Success state: green confirmation prompting the user to restart the CLI.
      return _WideButton(
        label: '需重启${widget.toolName}后生效',
        color: AppColors.successBackground,
        textColor: AppColors.successText,
        onPressed: _isApplying ? null : _pickBilling,
      );
    }

    final baseLabel = isInitialized ? '更换计费' : '初始化';
    return _WideButton(
      label: baseLabel,
      loading: _isApplying,
      color: isInitialized
          ? AppColors.secondaryButtonBackground
          : AppColors.orange,
      textColor: isInitialized ? AppColors.label : CupertinoColors.white,
      onPressed: disabled ? null : _pickBilling,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.tertiaryLabel),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: child),
        ),
      ],
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.value);

  final String? value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;
    return Text(
      isEmpty ? '—' : value!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isEmpty ? AppColors.placeholderText : AppColors.label,
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.planType});

  final String planType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.planBadgeBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        planType,
        style: const TextStyle(
          color: AppColors.planBadgeText,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  /// Shows a macOS-style spinner to the left of [label] while an operation runs.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                CupertinoActivityIndicator(radius: 8, color: textColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(height: 1, child: ColoredBox(color: AppColors.divider)),
    );
  }
}
