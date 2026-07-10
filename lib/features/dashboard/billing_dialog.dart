import 'package:desktop/core/utils/formatters.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// Presents the macOS-style billing picker for a tool and resolves to the
/// chosen `user_pack_id` — 0 for pay-as-you-go (按量计费) or a subscription
/// pack id. Resolves to null when the user cancels.
Future<int?> showBillingDialog(
  BuildContext context, {
  required String toolName,
  required int currentUserPackId,
  required List<UserPack> packs,
}) {
  return showCupertinoDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _BillingDialog(
      toolName: toolName,
      currentUserPackId: currentUserPackId,
      packs: packs,
    ),
  );
}

/// Sentinel `user_pack_id` for the pay-as-you-go option.
const int _payAsYouGoId = 0;

class _BillingDialog extends StatefulWidget {
  const _BillingDialog({
    required this.toolName,
    required this.currentUserPackId,
    required this.packs,
  });

  final String toolName;
  final int currentUserPackId;
  final List<UserPack> packs;

  @override
  State<_BillingDialog> createState() => _BillingDialogState();
}

class _BillingDialogState extends State<_BillingDialog> {
  late int _selected = widget.currentUserPackId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.barrier,
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.toolName} 计费方式',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '选择后将重新写入本地凭据。',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.tertiaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  children: [
                    _BillingOption(
                      title: '按量计费',
                      subtitle: '按实际用量从账户余额扣费',
                      selected: _selected == _payAsYouGoId,
                      onTap: () => setState(() => _selected = _payAsYouGoId),
                    ),
                    for (final pack in widget.packs)
                      _BillingOption(
                        title: pack.product.name,
                        subtitle: _packSubtitle(pack),
                        selected: _selected == pack.id,
                        onTap: () => setState(() => _selected = pack.id),
                      ),
                  ],
                ),
              ),
            ),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: '取消',
                      color: AppColors.secondaryButtonBackground,
                      textColor: AppColors.label,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: '确定',
                      color: AppColors.blue,
                      textColor: CupertinoColors.white,
                      onPressed: () => Navigator.of(context).pop(_selected),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _packSubtitle(UserPack pack) {
    final remaining =
        '剩余额度 ${_amount(pack.remainAmount)}'
        ' / ${_amount(pack.product.balance)}';
    final expireAt = pack.expireAt;
    if (expireAt == null) {
      return remaining;
    }
    return '$remaining · 有效期至 ${formatDate(expireAt)}';
  }
}

class _BillingOption extends StatelessWidget {
  const _BillingOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.blue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.selectedOptionBackground
                : AppColors.optionBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.blue;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : CupertinoColors.white,
        border: Border.all(
          color: selected ? accent : AppColors.disabledButtonBackground,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(
              CupertinoIcons.check_mark,
              size: 13,
              color: CupertinoColors.white,
            )
          : null,
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
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
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: AppColors.divider),
    );
  }
}

/// Renders a balance without a trailing ".0" for whole numbers.
String _amount(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
