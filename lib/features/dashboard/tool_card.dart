import 'dart:async';

import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/features/dashboard/billing_dialog.dart';
import 'package:flutter/cupertino.dart';

/// Dashboard card for a local AI CLI tool's configuration (Codex, Claude Code).
///
/// Always surfaces the account fields (empty until initialized); the header
/// shows a running pill once initialized, or an idle badge otherwise. The
/// bottom action is `更换计费` when initialized, or `初始化` when not — both open
/// the billing picker and apply the chosen method via [onApplyBilling].
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isWorking,
    required this.packs,
    required this.onApplyBilling,
  });

  /// The 48x48 brand icon tile shown at the start of the header.
  final Widget leading;
  final String title;
  final String subtitle;
  final ToolStatus status;
  final bool isWorking;

  /// The subscriptions offered in the billing picker.
  final List<UserPack> packs;

  /// Applies the chosen billing method: 0 for pay-as-you-go (按量计费) or a
  /// subscription pack id. Resolves to true when the credentials were
  /// rewritten successfully, which triggers the "restart to take effect" hint.
  final Future<bool> Function(int userPackId) onApplyBilling;

  @override
  Widget build(BuildContext context) {
    final account = status.account;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
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
            isRunning: account != null,
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

class _Header extends StatelessWidget {
  const _Header({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isRunning,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool isRunning;

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
                    color: Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          isRunning ? const _RunningPill() : const _IdlePill(),
        ],
      ),
    );
  }
}

class _RunningPill extends StatelessWidget {
  const _RunningPill();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF248A3D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F7EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: green),
          SizedBox(width: 6),
          Text(
            '正在运行',
            style: TextStyle(
              color: green,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdlePill extends StatelessWidget {
  const _IdlePill();

  @override
  Widget build(BuildContext context) {
    const gray = Color(0xFF8E8E93);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: gray),
          SizedBox(width: 6),
          Text(
            '未初始化',
            style: TextStyle(
              color: gray,
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
  final Future<bool> Function(int userPackId) onApplyBilling;

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

    final succeeded = await widget.onApplyBilling(selected);
    if (!mounted) {
      return;
    }

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
        color: const Color(0xFFE3F7EA),
        textColor: const Color(0xFF248A3D),
        onPressed: _isApplying ? null : _pickBilling,
      );
    }

    final baseLabel = isInitialized ? '更换计费' : '初始化';
    return _WideButton(
      label: baseLabel,
      loading: _isApplying,
      color: isInitialized ? const Color(0xFFEAEAEC) : const Color(0xFFFF9500),
      textColor: isInitialized
          ? const Color(0xFF1D1D1F)
          : CupertinoColors.white,
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
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
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
        color: isEmpty ? const Color(0xFFB0B0B5) : const Color(0xFF1D1D1F),
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
        color: const Color(0xFFE8EBFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        planType,
        style: const TextStyle(
          color: Color(0xFF3B5BDB),
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
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFECECEF))),
    );
  }
}
