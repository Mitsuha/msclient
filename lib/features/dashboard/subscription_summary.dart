import 'package:desktop/core/utils/formatters.dart';
import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/features/dashboard/pack_status_presentation.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/summary_icon.dart';
import 'package:flutter/cupertino.dart';

class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({super.key, required this.packs});

  final List<UserPack> packs;

  @override
  Widget build(BuildContext context) {
    if (packs.isEmpty) {
      return const _EmptySubscription();
    }

    return Column(
      children: [
        for (var i = 0; i < packs.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: _Divider(),
            ),
          _PackRow(pack: packs[i]),
        ],
      ],
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack});

  final UserPack pack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SummaryIcon(
            icon: CupertinoIcons.sparkles,
            color: AppColors.blue,
            background: AppColors.blueChipBackground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pack.product.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      packStatusText(pack.status),
                      style: TextStyle(
                        color: packStatusColor(pack.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _UsageBar(
                  remain: pack.remainAmount,
                  total: pack.product.balance,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '剩余额度 ${_amount(pack.remainAmount)} / ${_amount(pack.product.balance)}',
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (pack.expireAt != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        '有效期至 ${formatDate(pack.expireAt!)}',
                        style: const TextStyle(
                          color: AppColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin progress bar showing how much of a pack's balance remains.
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.remain, required this.total});

  final num remain;
  final num total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? (remain / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: AppColors.blueChipBackground,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.toDouble(),
          child: Container(color: AppColors.blue),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.hoverBackground);
  }
}

/// Renders a balance without a trailing ".0" for whole numbers.
String _amount(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

class _EmptySubscription extends StatelessWidget {
  const _EmptySubscription();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          SummaryIcon(
            icon: CupertinoIcons.tray,
            color: AppColors.tertiaryLabel,
            background: AppColors.hoverBackground,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '暂无已购买套餐',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 3),
                Text(
                  '购买套餐后会在这里显示。',
                  style: TextStyle(
                    color: AppColors.secondaryLabel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
