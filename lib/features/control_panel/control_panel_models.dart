import 'dart:convert';

enum RuntimeState { loading, conflict, uninitialized, running, error }

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

class ConflictProcess {
  const ConflictProcess({required this.pid, required this.command});

  final int pid;
  final String command;
}

class InitializationStatus {
  const InitializationStatus({
    required this.authPath,
    required this.envPath,
    required this.hasAuthFile,
    required this.hasAccessToken,
    required this.hasAccountSharingMemberId,
    required this.hasHttpProxy,
    required this.hasHttpsProxy,
  });

  final String authPath;
  final String envPath;
  final bool hasAuthFile;
  final bool hasAccessToken;
  final bool hasAccountSharingMemberId;
  final bool hasHttpProxy;
  final bool hasHttpsProxy;

  bool get isInitialized =>
      hasAccessToken &&
      hasAccountSharingMemberId &&
      hasHttpProxy &&
      hasHttpsProxy;
}

class ControlPanelSnapshot {
  const ControlPanelSnapshot({
    required this.state,
    required this.account,
    required this.initialization,
    this.conflicts = const [],
    this.message,
  });

  final RuntimeState state;
  final AccountSummary account;
  final InitializationStatus initialization;
  final List<ConflictProcess> conflicts;
  final String? message;

  bool get isBusy => state == RuntimeState.loading;
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
