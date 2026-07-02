import 'dart:convert';

import 'package:desktop/features/models/account_models.dart';
import 'package:desktop/features/models/dashboard_models.dart';
import 'package:desktop/features/models/pack_models.dart';

enum RuntimeState {
  loading,
  conflict,
  rootCertificateMissing,
  uninitialized,
  running,
  error,
}

class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.nickname,
    required this.balance,
    required this.planName,
    required this.planExpiresAt,
  });

  final String account;
  final String nickname;
  final String balance;
  final String planName;
  final String planExpiresAt;
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.overview,
    required this.packs,
  });

  final UserProfile user;
  final DashboardOverview overview;
  final List<UserPack> packs;

  AccountSummary get accountSummary {
    final primaryPack = packs.where((pack) => pack.isActive).firstOrNull;
    return AccountSummary(
      account: user.displayAccount,
      nickname: user.nickname.isEmpty ? '-' : user.nickname,
      balance: _money(overview.balance),
      planName: primaryPack?.product.name ?? '暂无套餐',
      planExpiresAt: primaryPack?.expireAt == null
          ? '-'
          : _date(primaryPack!.expireAt!),
    );
  }
}

class ConflictProcess {
  const ConflictProcess({required this.pid, required this.command});

  final int pid;
  final String command;
}

class InitializationStatus {
  const InitializationStatus({
    required this.authPath,
    required this.envPath,
    required this.configPath,
    required this.hasAuthFile,
    required this.hasAccessToken,
    required this.hasAccountSharingMemberId,
    required this.hasHttpProxy,
    required this.hasHttpsProxy,
    required this.hasCodexProviderOverride,
  });

  final String authPath;
  final String envPath;
  final String configPath;
  final bool hasAuthFile;
  final bool hasAccessToken;
  final bool hasAccountSharingMemberId;
  final bool hasHttpProxy;
  final bool hasHttpsProxy;
  final bool hasCodexProviderOverride;

  bool get isInitialized =>
      hasAccessToken &&
      hasAccountSharingMemberId &&
      hasHttpProxy &&
      hasHttpsProxy &&
      !hasCodexProviderOverride;
}

class LocalConfigurationStatus {
  const LocalConfigurationStatus({
    required this.codexDirectoryPath,
    required this.claudeDirectoryPath,
    required this.isCodexInstalled,
    required this.isClaudeInstalled,
    required this.rootCertificate,
  });

  final String codexDirectoryPath;
  final String claudeDirectoryPath;
  final bool isCodexInstalled;
  final bool isClaudeInstalled;
  final RootCertificateStatus rootCertificate;
}

class RootCertificateStatus {
  const RootCertificateStatus({
    required this.assetPath,
    required this.isInstalled,
  });

  final String assetPath;
  final bool isInstalled;
}

class ControlPanelSnapshot {
  const ControlPanelSnapshot({
    required this.state,
    required this.account,
    required this.initialization,
    required this.localConfiguration,
    this.dashboard,
    this.conflicts = const [],
    this.message,
  });

  final RuntimeState state;
  final AccountSummary account;
  final InitializationStatus initialization;
  final LocalConfigurationStatus localConfiguration;
  final DashboardData? dashboard;
  final List<ConflictProcess> conflicts;
  final String? message;

  bool get isBusy => state == RuntimeState.loading;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

String _money(num value) {
  return '\$${value.toStringAsFixed(2)}';
}

String _date(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}
