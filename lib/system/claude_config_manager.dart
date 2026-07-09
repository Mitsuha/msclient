import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/tool_config_manager.dart';
import 'package:flutter/foundation.dart';

/// The macOS Keychain generic-password item that Claude Code stores its
/// credentials under.
const String _keychainService = 'Claude Code-credentials';

/// Reads and writes the local Claude Code configuration.
///
/// Applying MirrorStages auth touches two places:
///
/// * the **credentials store** — on macOS the login Keychain (item
///   `Claude Code-credentials`), on Windows/Linux `~/.claude/.credentials.json`
///   — which holds the `claudeAiOauth` block extracted from
///   `POST /user/claude-auth`;
/// * `~/.claude.json` — Claude Code's global profile (a sibling of the
///   `~/.claude` directory) — into which the account identity from the same
///   response is merged.
class ClaudeConfigManager implements ToolConfigManager {
  ClaudeConfigManager({required this._home});

  final HomeDirectory _home;

  @override
  Future<String> directoryPath() async => '${await _home.resolve()}/.claude';

  @override
  Future<bool> isInstalled() async =>
      Directory(await directoryPath()).exists();

  Future<String> _credentialsFilePath() async =>
      '${await directoryPath()}/.credentials.json';

  /// Path of Claude Code's global profile, `~/.claude.json` — note this is a
  /// sibling of the `~/.claude` directory, not a file inside it.
  Future<String> _profileFilePath() async =>
      '${await _home.resolve()}/.claude.json';

  /// Sub-directory of `~/.claude` that holds the backed-up original config.
  static const _backupDirectoryName = 'old_config';
  static const _settingsFileName = 'settings.json';
  static const _credentialsFileName = '.credentials.json';

  /// Whether the stored credentials decode into a MirrorStages account —
  /// the check side of the credentials init step.
  Future<bool> hasMirrorStagesCredentials() async =>
      (await readStatus()).isInitialized;

  /// Applies the MirrorStages auth returned by `POST /user/claude-auth`.
  ///
  /// Two things are written from the single [claudeAuth] response:
  ///
  /// 1. its `claudeAiOauth` block becomes the local credentials
  ///    ([writeCredentials]);
  /// 2. its account identity (`oauthAccount` / `userID` / `machineID`) is
  ///    merged into `~/.claude.json`, which is also marked as onboarded
  ///    ([_writeProfile]).
  ///
  /// Does not back up the user's originals — the backup is taken once, up
  /// front, by [preserveOriginals] during a full first-time initialization.
  Future<void> writeAuth(Map<String, dynamic> claudeAuth) async {
    await writeCredentials({'claudeAiOauth': claudeAuth['claudeAiOauth']});
    await _writeProfile(claudeAuth);
  }

  /// Stores [credentials] verbatim as the local Claude Code credentials (the
  /// macOS Keychain item, or `.credentials.json` on Windows/Linux). Callers
  /// pass the `{claudeAiOauth: ...}` block, not the whole auth response.
  ///
  /// Does not back up the user's original — see [writeAuth].
  Future<void> writeCredentials(Map<String, dynamic> credentials) async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    final encoded = jsonEncode(credentials);
    if (Platform.isMacOS) {
      await _writeToKeychain(encoded);
    } else {
      await _writeToFile(encoded);
    }
  }

  /// Merges the account identity from a `POST /user/claude-auth` response into
  /// `~/.claude.json`, preserving every other field Claude Code keeps there
  /// (project history, MCP servers, …), and marks onboarding complete.
  ///
  /// Only the identity fields the server actually returned are copied, so a
  /// field the response omits never clobbers an existing value with null.
  Future<void> _writeProfile(Map<String, dynamic> claudeAuth) async {
    final file = File(await _profileFilePath());
    final profile = await _readJsonObject(file);
    for (final key in const ['oauthAccount', 'userID', 'machineID']) {
      if (claudeAuth.containsKey(key)) {
        profile[key] = claudeAuth[key];
      }
    }
    profile['hasCompletedOnboarding'] = true;

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(profile)}\n');
  }

  /// Whether `settings.json` routes Claude Code through a proxy: its `env`
  /// carries non-empty `HTTPS_PROXY` and `HTTP_PROXY` entries.
  Future<bool> hasProxySettings() async {
    try {
      final file = File('${await directoryPath()}/$_settingsFileName');
      if (!await file.exists()) {
        return false;
      }
      final settings = jsonDecode(await file.readAsString());
      if (settings is! Map) {
        return false;
      }
      final env = settings['env'];
      if (env is! Map) {
        return false;
      }
      bool has(String key) {
        final value = env[key];
        return value is String && value.isNotEmpty;
      }

      return has('HTTPS_PROXY') && has('HTTP_PROXY');
    } catch (_) {
      return false;
    }
  }

  /// Points the `env` proxies in `settings.json` at [proxyUrl], preserving any
  /// other settings the user keeps in the file; the theme/model defaults are
  /// only pinned when absent.
  ///
  /// Does not back up the user's original — the backup is taken once, up front,
  /// by [preserveOriginals] during a full first-time initialization.
  Future<void> writeProxySettings(String proxyUrl) async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    final live = File('$claudeDir/$_settingsFileName');
    final settings = await _readSettings(live);
    final env = settings['env'] is Map
        ? Map<String, dynamic>.from(settings['env'] as Map)
        : <String, dynamic>{};
    env['HTTPS_PROXY'] = proxyUrl;
    env['HTTP_PROXY'] = proxyUrl;
    settings['env'] = env;
    settings.putIfAbsent('theme', () => 'light');
    settings.putIfAbsent('model', () => 'opus[1m]');

    const encoder = JsonEncoder.withIndent('  ');
    await live.writeAsString('${encoder.convert(settings)}\n');
  }

  /// Removes the `HTTPS_PROXY` / `HTTP_PROXY` entries from `settings.json`'s
  /// `env`, leaving every other setting — and every other env var — untouched.
  /// A missing file, or one without an `env` proxy, is a no-op.
  Future<void> clearProxySettings() async {
    final file = File('${await directoryPath()}/$_settingsFileName');
    if (!await file.exists()) {
      return;
    }
    final settings = await _readSettings(file);
    if (settings['env'] is! Map) {
      return;
    }
    final env = Map<String, dynamic>.from(settings['env'] as Map)
      ..remove('HTTPS_PROXY')
      ..remove('HTTP_PROXY');
    settings['env'] = env;

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(settings)}\n');
  }

  /// The current `settings.json` as a mutable map; a missing or malformed file
  /// yields an empty map so the write can start from the defaults.
  Future<Map<String, dynamic>> _readSettings(File file) => _readJsonObject(file);

  /// Parses [file] as a JSON object, returning a mutable map. A missing or
  /// malformed file yields an empty map so a merging write can start clean.
  Future<Map<String, dynamic>> _readJsonObject(File file) async {
    try {
      if (!await file.exists()) {
        return <String, dynamic>{};
      }
      final parsed = jsonDecode(await file.readAsString());
      return parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Snapshots the user's original `settings.json` and credentials into
  /// `~/.claude/old_config` (each at most once) before MirrorStages overwrites
  /// them. Called only for a full first-time initialization, so no other entry
  /// point creates the backup.
  ///
  /// Credentials are snapshotted before the credentials step runs, so the
  /// backup captures the user's file rather than the MirrorStages one.
  Future<void> preserveOriginals() async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    final backupDir = Directory('$claudeDir/$_backupDirectoryName');
    await _backupFileOnce(
      live: File('$claudeDir/$_settingsFileName'),
      backup: File('${backupDir.path}/$_settingsFileName'),
      backupDir: backupDir,
    );
    await _preserveCredentialsOriginal(claudeDir);
  }

  /// Snapshots the user's original credentials into `~/.claude/old_config`
  /// once, before MirrorStages overwrites them, so the change can be rolled
  /// back.
  ///
  /// Credentials are a file on Windows/Linux but live in the macOS Keychain —
  /// there we read the current Keychain item and snapshot it into
  /// `old_config/.credentials.json` so restore can write it back. The backup is
  /// written at most once, so repeated initializations never clobber the
  /// pristine original with a MirrorStages-generated one.
  Future<void> _preserveCredentialsOriginal(String claudeDir) async {
    final backupDir = Directory('$claudeDir/$_backupDirectoryName');
    final credentialsBackup = File('${backupDir.path}/$_credentialsFileName');
    if (await credentialsBackup.exists()) {
      return;
    }
    if (Platform.isMacOS) {
      final existing = await _readFromKeychain();
      if (existing != null) {
        await backupDir.create(recursive: true);
        await credentialsBackup.writeAsString(existing);
      }
    } else {
      await _backupFileOnce(
        live: File('$claudeDir/$_credentialsFileName'),
        backup: credentialsBackup,
        backupDir: backupDir,
      );
    }
  }

  Future<void> _backupFileOnce({
    required File live,
    required File backup,
    required Directory backupDir,
  }) async {
    if (await live.exists() && !await backup.exists()) {
      await backupDir.create(recursive: true);
      await live.copy(backup.path);
    }
  }

  /// Whether a `~/.claude/old_config` backup exists that can be restored.
  Future<bool> hasRestorableBackup() async {
    final backupDir = Directory(
      '${await directoryPath()}/$_backupDirectoryName',
    );
    if (!await backupDir.exists()) {
      return false;
    }
    return await File('${backupDir.path}/$_settingsFileName').exists() ||
        await File('${backupDir.path}/$_credentialsFileName').exists();
  }

  /// Restores the user's original Claude Code configuration from
  /// `~/.claude/old_config`: `settings.json` and the credentials (Keychain on
  /// macOS, `.credentials.json` elsewhere). A missing backup file means the
  /// original did not exist, so the MirrorStages-written live copy is removed
  /// to return to a pristine state. Throws [ClaudeConfigRestoreException] when
  /// there is nothing to restore. Finally clears the backup directory.
  Future<void> restoreOriginals() async {
    final claudeDir = await directoryPath();
    final backupDir = Directory('$claudeDir/$_backupDirectoryName');
    if (!await hasRestorableBackup()) {
      throw const ClaudeConfigRestoreException('未找到可恢复的原始 Claude 配置。');
    }

    await _restoreFile(
      backup: File('${backupDir.path}/$_settingsFileName'),
      live: File('$claudeDir/$_settingsFileName'),
    );

    final credentialsBackup = File('${backupDir.path}/$_credentialsFileName');
    if (Platform.isMacOS) {
      if (await credentialsBackup.exists()) {
        await _writeToKeychain(await credentialsBackup.readAsString());
      } else {
        await _deleteFromKeychain();
      }
    } else {
      await _restoreFile(
        backup: credentialsBackup,
        live: File('$claudeDir/$_credentialsFileName'),
      );
    }

    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }

  /// Copies [backup] back over [live] when the backup exists; otherwise removes
  /// [live] (it was MirrorStages-created, so "pristine" means absent).
  Future<void> _restoreFile({required File backup, required File live}) async {
    if (await backup.exists()) {
      await backup.copy(live.path);
    } else if (await live.exists()) {
      await live.delete();
    }
  }

  /// Reports the Claude Code initialization state. Initialization is decided by
  /// the credentials store — the account counts as MirrorStages only when its
  /// access token carries a `user_pack_id` ([parseClaudeUserPackId]) — while the
  /// account's display fields (email, name, plan) are read from the
  /// `~/.claude.json` profile's `oauthAccount` ([claudeAccountFromProfile]).
  ///
  /// Any failure — the item/file is missing, the JSON is malformed, or the
  /// access token cannot be parsed — is treated as [ToolStatus.uninitialized]
  /// rather than surfaced as an error.
  @override
  Future<ToolStatus> readStatus() async {
    final credentials = await _readCredentials();
    if (credentials == null) {
      return const ToolStatus.uninitialized();
    }
    final userPackId = parseClaudeUserPackId(credentials);
    if (userPackId == null) {
      return const ToolStatus.uninitialized();
    }
    final profile = await _readJsonObject(File(await _profileFilePath()));
    return ToolStatus.initialized(claudeAccountFromProfile(profile, userPackId));
  }

  Future<String?> _readCredentials() async {
    try {
      if (Platform.isMacOS) {
        return await _readFromKeychain();
      }
      final file = File(await _credentialsFilePath());
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeToKeychain(String credentials) async {
    // Delete any existing item first, then re-add with `-A`. `-U` updates the
    // stored value in place but does NOT reset a pre-existing (restrictive)
    // access-control list — that stale ACL is what triggers access prompts.
    // Recreating the item guarantees the most permissive ACL on every write:
    // any application may read it without a warning prompt.
    await _deleteFromKeychain();
    final result = await Process.run('/usr/bin/security', [
      'add-generic-password',
      '-a',
      _keychainAccount,
      '-s',
      _keychainService,
      '-w',
      credentials,
      // Allow any application to read this item without warning (most
      // permissive access; no per-access prompt).
      '-A',
    ]);
    if (result.exitCode != 0) {
      throw ClaudeConfigException(_processFailureDetails(result));
    }
  }

  /// Removes the Claude Code Keychain item if present. A missing item is not an
  /// error — the desired end state is simply that no item exists.
  Future<void> _deleteFromKeychain() async {
    await Process.run('/usr/bin/security', [
      'delete-generic-password',
      '-s',
      _keychainService,
    ]);
  }

  Future<String?> _readFromKeychain() async {
    final result = await Process.run('/usr/bin/security', [
      'find-generic-password',
      '-s',
      _keychainService,
      '-w',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString();
    // `security -w` terminates its output with a newline.
    return output.endsWith('\n')
        ? output.substring(0, output.length - 1)
        : output;
  }

  Future<void> _writeToFile(String credentials) async {
    final file = File(await _credentialsFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(credentials);
  }

  String get _keychainAccount =>
      Platform.environment['USER'] ??
      Platform.environment['LOGNAME'] ??
      'mirrorstages';

  String _processFailureDetails(ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    return result.stdout.toString().trim();
  }
}

const String _accessTokenPrefix = 'sk-ant-oat01-';

/// Reads the `user_pack_id` out of a Claude Code credentials JSON string, or
/// returns null when the credentials are not a MirrorStages access token.
///
/// The `claudeAiOauth.accessToken` is `sk-ant-oat01-<content>-<signature>`
/// where `<content>` is the URL-safe, unpadded base64 of
/// `user_id|account_sharing_member_id|user_pack_id|` followed by 8 random
/// padding bytes. Only the ASCII prefix up to the 3rd `|` is meaningful, so the
/// pack id (the 3rd field, `"0"` for pay-as-you-go / 按量计费) is read from the
/// raw bytes without UTF-8 decoding the random padding tail.
@visibleForTesting
int? parseClaudeUserPackId(String credentialsJson) {
  try {
    final root = jsonDecode(credentialsJson);
    if (root is! Map) {
      return null;
    }
    final oauth = root['claudeAiOauth'];
    if (oauth is! Map) {
      return null;
    }
    final accessToken = oauth['accessToken'];
    if (accessToken is! String || !accessToken.startsWith(_accessTokenPrefix)) {
      return null;
    }

    final content = accessToken
        .substring(_accessTokenPrefix.length)
        .split('-')
        .first;
    final bytes = base64Url.decode(base64Url.normalize(content));
    const pipe = 0x7c; // '|'
    final pipes = <int>[];
    for (var i = 0; i < bytes.length && pipes.length < 3; i++) {
      if (bytes[i] == pipe) {
        pipes.add(i);
      }
    }
    if (pipes.length < 3) {
      return null;
    }
    // The pack id lives between the 2nd and 3rd '|'; those first three fields
    // are ASCII digits, so decoding just that slice never hits the padding.
    return int.tryParse(ascii.decode(bytes.sublist(pipes[1] + 1, pipes[2]))) ??
        0;
  } catch (_) {
    return null;
  }
}

/// Builds the signed-in Claude account from the `~/.claude.json` profile: the
/// email, display name, and plan come from its `oauthAccount`
/// (`emailAddress` / `displayName` / `organizationRateLimitTier`), while the
/// billing [userPackId] is carried over from the access token.
@visibleForTesting
ToolAccount claudeAccountFromProfile(
  Map<String, dynamic> profile,
  int userPackId,
) {
  final oauthAccount = profile['oauthAccount'];
  final account = oauthAccount is Map ? oauthAccount : const <String, dynamic>{};
  final email = account['emailAddress']?.toString() ?? '';
  final displayName = account['displayName']?.toString() ?? '';
  return ToolAccount(
    email: email,
    name: displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@').first : email),
    planType: _planTypeFor(account['organizationRateLimitTier']?.toString()),
    userPackId: userPackId,
  );
}

String _planTypeFor(String? rateLimitTier) {
  return switch (rateLimitTier) {
    'default_claude_max_20x' => 'Max 20X',
    'default_claude_max_5x' => 'Max 5X',
    _ => 'Pro',
  };
}

class ClaudeConfigException implements Exception {
  const ClaudeConfigException(this.details);

  final String details;

  @override
  String toString() {
    if (details.isEmpty) {
      return '无法写入 Claude Code 凭据。';
    }
    return '无法写入 Claude Code 凭据。$details';
  }
}

class ClaudeConfigRestoreException implements Exception {
  const ClaudeConfigRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
