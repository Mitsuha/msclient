/// The signed-in account for a local AI CLI tool (Codex / Claude Code),
/// decoded from that tool's stored credentials.
class ToolAccount {
  const ToolAccount({
    required this.email,
    required this.name,
    required this.planType,
    this.userPackId = 0,
  });

  /// Account email.
  final String email;

  /// The part of [email] before `@`.
  final String name;

  /// Display-ready plan label.
  final String planType;

  /// The subscription pack the tool's credentials are currently billed
  /// against, or 0 when it is billed pay-as-you-go (按量计费).
  final int userPackId;
}

/// Whether a local tool is initialized for MirrorStages, and — when it is —
/// the account it is authorized as.
///
/// Initialization is decided solely by whether the tool's stored credentials
/// can be read and decoded into an account; any failure along the way is
/// treated as [ToolStatus.uninitialized].
class ToolStatus {
  const ToolStatus._({required this.isInitialized, required this.account});

  const ToolStatus.initialized(ToolAccount account)
    : this._(isInitialized: true, account: account);

  const ToolStatus.uninitialized()
    : this._(isInitialized: false, account: null);

  final bool isInitialized;
  final ToolAccount? account;
}
