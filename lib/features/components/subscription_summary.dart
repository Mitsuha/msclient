import 'package:flutter/cupertino.dart';

import 'package:desktop/features/components/summary_icon.dart';
import 'package:desktop/features/models/pack_models.dart';

class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({super.key, required this.packs});

  final List<UserPack> packs;

  @override
  Widget build(BuildContext context) {
    if (packs.isEmpty) {
      return const _EmptySubscription();
    }

    final pack = packs.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          const SummaryIcon(
            icon: CupertinoIcons.sparkles,
            color: Color(0xFF007AFF),
            background: Color(0xFFE8F2FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.product.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _packSubtitle(pack),
                  style: const TextStyle(
                    color: Color(0xFF6E6E73),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _packStatusText(pack.status),
            style: TextStyle(
              color: _packStatusColor(pack.status),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _packSubtitle(UserPack pack) {
    final expireAt = pack.expireAt;
    if (expireAt == null) {
      return '剩余额度 ${pack.remainAmount}';
    }
    return '有效期至 ${_formatDate(expireAt)}';
  }

  String _packStatusText(UserPackStatus status) {
    return switch (status) {
      UserPackStatus.active => '已购买',
      UserPackStatus.exhausted => '已耗尽',
      UserPackStatus.expired => '已过期',
      UserPackStatus.unknown => '未知',
    };
  }

  Color _packStatusColor(UserPackStatus status) {
    return switch (status) {
      UserPackStatus.active => const Color(0xFF34C759),
      UserPackStatus.exhausted => const Color(0xFFFF9500),
      UserPackStatus.expired => const Color(0xFF8E8E93),
      UserPackStatus.unknown => const Color(0xFF8E8E93),
    };
  }
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
            color: Color(0xFF8E8E93),
            background: Color(0xFFF2F2F7),
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
                  style: TextStyle(color: Color(0xFF6E6E73), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
