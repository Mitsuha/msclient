import 'package:desktop/core/utils/formatters.dart';
import 'package:desktop/data/models/account_models.dart';
import 'package:desktop/data/models/dashboard_models.dart';
import 'package:desktop/data/models/pack_models.dart';

/// Display-ready summary of the signed-in account.
class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.nickname,
    required this.balance,
    required this.planName,
    required this.planExpiresAt,
  });

  factory AccountSummary.fromDashboard(DashboardData dashboard) {
    final primaryPack = dashboard.packs
        .where((pack) => pack.isActive)
        .firstOrNull;
    return AccountSummary(
      account: dashboard.user.displayAccount,
      nickname: dashboard.user.nickname.isEmpty ? '-' : dashboard.user.nickname,
      balance: formatMoney(dashboard.overview.balance),
      planName: primaryPack?.product.name ?? '暂无套餐',
      planExpiresAt: primaryPack?.expireAt == null
          ? '-'
          : formatDate(primaryPack!.expireAt!),
    );
  }

  final String account;
  final String nickname;
  final String balance;
  final String planName;
  final String planExpiresAt;
}

/// The remote data the dashboard is rendered from.
class DashboardData {
  const DashboardData({
    required this.user,
    required this.overview,
    required this.packs,
  });

  final UserProfile user;
  final DashboardOverview overview;
  final List<UserPack> packs;
}
