import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/safe_fs.dart';
import 'package:desktop/system/tool_config_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// The macOS Keychain generic-password item that Claude Code stores its
/// credentials under.
const String _keychainService = 'Claude Code-credentials';

/// Reads and writes Claude Code credentials, settings, and profile data.
class ClaudeConfigManager implements ToolConfigManager {
  ClaudeConfigManager({required this._home});

  final HomeDirectory _home;

  @override
  Future<String> directoryPath() async =>
      path.join(await _home.resolve(), '.claude');

  @override
  Future<bool> isInstalled() async =>
      safeExists(Directory(await directoryPath()));

  Future<String> _credentialsFilePath() async =>
      path.join(await directoryPath(), _credentialsFileName);

  /// Path of Claude Code's global profile, `~/.claude.json` — note this is a
  /// sibling of the `~/.claude` directory, not a file inside it.
  Future<String> _profileFilePath() async =>
      path.join(await _home.resolve(), '.claude.json');

  Future<String> _certificatePath() async =>
      path.join(await _home.resolve(), '.mstages', 'ms.cer');

  /// Sub-directory of `~/.claude` that holds the backed-up original config.
  static const _backupDirectoryName = 'old_config';
  static const _settingsFileName = 'settings.json';
  static const _credentialsFileName = '.credentials.json';

  /// Backup of the profile fields managed by MirrorStages.
  static const _profileBackupFileName = 'claude-profile.json';
  static const _profileManagedKeys = [
    'oauthAccount',
    'userID',
    'machineID',
    'hasCompletedOnboarding',
  ];

  /// Whether the stored credentials decode into a MirrorStages account —
  /// the check side of the credentials init step.
  Future<bool> hasMirrorStagesCredentials() async =>
      (await readStatus()).isInitialized;

  // --- ToolConfigManager proxy/backup lifecycle (delegates to the concrete
  // per-file methods below; the initializer steps use those directly) ---

  @override
  Future<bool> hasIssuedCredentials() => hasMirrorStagesCredentials();

  @override
  Future<void> writeProxy(String proxyUrl) => writeProxySettings(proxyUrl);

  @override
  Future<void> stripProxy() => clearProxySettings();

  @override
  Future<void> clearProxy() => clearProxySettings();

  /// Clears account credentials and settings before API-key mode writes a
  /// replacement, preventing a stale proxy from intercepting key traffic.
  @override
  Future<void> clearAccountConfig() async {
    await _clearCredentials();
    final settings = File(path.join(await directoryPath(), _settingsFileName));
    if (await settings.exists()) {
      await settings.delete();
    }
  }

  /// Removes the stored credentials: the Keychain item on macOS, the
  /// `.credentials.json` file elsewhere. A missing item is not an error.
  Future<void> _clearCredentials() async {
    if (Platform.isMacOS) {
      await _deleteFromKeychain();
      return;
    }
    final file = File(await _credentialsFilePath());
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Writes credentials and profile data from `/user/claude-auth`.
  Future<void> writeAuth(Map<String, dynamic> claudeAuth) async {
    await writeCredentials({'claudeAiOauth': claudeAuth['claudeAiOauth']});
    await _writeProfile(claudeAuth);
  }

  /// Stores credentials in Keychain or `.credentials.json`.
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

  /// Merges returned identity fields into `~/.claude.json`.
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

  /// Checks whether Claude uses the configured local proxy and certificate.
  Future<bool> hasProxySettings() async {
    try {
      final file = File(path.join(await directoryPath(), _settingsFileName));
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
      bool matches(String key) => env[key] == AppConfig.singboxLocalProxyUrl;
      return matches('HTTPS_PROXY') &&
          matches('HTTP_PROXY') &&
          env['NODE_EXTRA_CA_CERTS'] == await _certificatePath();
    } catch (_) {
      return false;
    }
  }

  /// Replaces `settings.json` env with the selected proxy configuration.
  Future<void> writeProxySettings(String proxyUrl) async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    final live = File(path.join(claudeDir, _settingsFileName));
    final settings = await _readSettings(live);
    settings['env'] = <String, dynamic>{
      'HTTPS_PROXY': proxyUrl,
      'HTTP_PROXY': proxyUrl,
      'NODE_EXTRA_CA_CERTS': await _certificatePath(),
    };
    settings.putIfAbsent('theme', () => 'light');
    settings.putIfAbsent('model', () => 'opus[1m]');

    const encoder = JsonEncoder.withIndent('  ');
    await live.writeAsString('${encoder.convert(settings)}\n');
  }

  /// Removes the `HTTPS_PROXY` / `HTTP_PROXY` entries from `settings.json`'s
  /// `env`, leaving every other setting — and every other env var — untouched.
  /// A missing file, or one without an `env` proxy, is a no-op.
  Future<void> clearProxySettings() async {
    final file = File(path.join(await directoryPath(), _settingsFileName));
    if (!await file.exists()) {
      return;
    }
    final settings = await _readSettings(file);
    if (settings['env'] is! Map) {
      return;
    }
    final env = Map<String, dynamic>.from(settings['env'] as Map)
      ..remove('HTTPS_PROXY')
      ..remove('HTTP_PROXY')
      ..remove('NODE_EXTRA_CA_CERTS');
    settings['env'] = env;

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(settings)}\n');
  }

  /// The current `settings.json` as a mutable map; a missing or malformed file
  /// yields an empty map so the write can start from the defaults.
  Future<Map<String, dynamic>> _readSettings(File file) =>
      _readJsonObject(file);

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

  /// Backs up the original Claude configuration once.
  @override
  Future<void> preserveOriginals() async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    final backupDir = Directory(path.join(claudeDir, _backupDirectoryName));
    await _backupFileOnce(
      live: File(path.join(claudeDir, _settingsFileName)),
      backup: File(path.join(backupDir.path, _settingsFileName)),
      backupDir: backupDir,
    );
    await _preserveCredentialsOriginal(claudeDir);
    await _preserveProfileOriginal(backupDir);
  }

  /// Backs up only the profile fields managed by MirrorStages.
  Future<void> _preserveProfileOriginal(Directory backupDir) async {
    final backup = File(path.join(backupDir.path, _profileBackupFileName));
    if (await backup.exists()) {
      return;
    }
    final profile = await _readJsonObject(File(await _profileFilePath()));
    final snapshot = <String, dynamic>{};
    for (final key in _profileManagedKeys) {
      if (profile.containsKey(key)) {
        snapshot[key] = profile[key];
      }
    }
    await backupDir.create(recursive: true);
    await backup.writeAsString(jsonEncode(snapshot));
  }

  /// Backs up the original credentials once.
  Future<void> _preserveCredentialsOriginal(String claudeDir) async {
    final backupDir = Directory(path.join(claudeDir, _backupDirectoryName));
    final credentialsBackup = File(
      path.join(backupDir.path, _credentialsFileName),
    );
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
        live: File(path.join(claudeDir, _credentialsFileName)),
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

  /// Checks whether a restorable backup exists.
  @override
  Future<bool> hasRestorableBackup() async {
    final backupDir = Directory(
      path.join(await directoryPath(), _backupDirectoryName),
    );
    if (!await safeExists(backupDir)) {
      return false;
    }
    return await safeExists(
          File(path.join(backupDir.path, _settingsFileName)),
        ) ||
        await safeExists(
          File(path.join(backupDir.path, _credentialsFileName)),
        ) ||
        await safeExists(
          File(path.join(backupDir.path, _profileBackupFileName)),
        );
  }

  /// Restores the original configuration and removes its backup.
  @override
  Future<void> restoreOriginals() async {
    final claudeDir = await directoryPath();
    final backupDir = Directory(path.join(claudeDir, _backupDirectoryName));
    if (!await hasRestorableBackup()) {
      throw const ClaudeConfigRestoreException('未找到可恢复的原始 Claude 配置。');
    }

    await _restoreFile(
      backup: File(path.join(backupDir.path, _settingsFileName)),
      live: File(path.join(claudeDir, _settingsFileName)),
    );

    final credentialsBackup = File(
      path.join(backupDir.path, _credentialsFileName),
    );
    if (Platform.isMacOS) {
      if (await credentialsBackup.exists()) {
        await _writeToKeychain(await credentialsBackup.readAsString());
      } else {
        await _deleteFromKeychain();
      }
    } else {
      await _restoreFile(
        backup: credentialsBackup,
        live: File(path.join(claudeDir, _credentialsFileName)),
      );
    }

    await _restoreProfile(backupDir);

    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }

  /// Restores the profile fields managed by MirrorStages.
  Future<void> _restoreProfile(Directory backupDir) async {
    final backup = File(path.join(backupDir.path, _profileBackupFileName));
    if (!await backup.exists()) {
      return;
    }
    final original = await _readJsonObject(backup);
    final profileFile = File(await _profileFilePath());
    final profile = await _readJsonObject(profileFile);
    for (final key in _profileManagedKeys) {
      if (original.containsKey(key)) {
        profile[key] = original[key];
      } else {
        profile.remove(key);
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    await profileFile.writeAsString('${encoder.convert(profile)}\n');
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

  /// Reads the Claude account from its local profile and credentials.
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
    return ToolStatus.initialized(
      claudeAccountFromProfile(
        profile,
        userPackId,
        credentialsJson: credentials,
      ),
    );
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
    // Recreate the item because `-U` preserves its old access-control list.
    // `-A` lets applications read it without prompting.
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

/// Reads `user_pack_id` from a MirrorStages Claude access token.
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

    // Decode the whole remainder because `-` can occur inside URL-safe base64.
    // Only bytes before the third `|` are used.
    final remainder = accessToken.substring(_accessTokenPrefix.length);
    final content = remainder.substring(
      0,
      remainder.length - remainder.length % 4,
    );
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

/// Builds the local Claude account.
@visibleForTesting
ToolAccount claudeAccountFromProfile(
  Map<String, dynamic> profile,
  int userPackId, {
  String? credentialsJson,
}) {
  final oauthAccount = profile['oauthAccount'];
  final account = oauthAccount is Map
      ? oauthAccount
      : const <String, dynamic>{};
  final email = account['emailAddress']?.toString() ?? '';
  final displayName = account['displayName']?.toString() ?? '';
  return ToolAccount(
    email: email,
    name: displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@').first : email),
    planType: _planTypeFor(_rateLimitTierFromCredentials(credentialsJson)),
    userPackId: userPackId,
  );
}

String? _rateLimitTierFromCredentials(String? credentialsJson) {
  if (credentialsJson == null) {
    return null;
  }
  try {
    final root = jsonDecode(credentialsJson);
    if (root is! Map) {
      return null;
    }
    final oauth = root['claudeAiOauth'];
    return oauth is Map ? oauth['rateLimitTier']?.toString() : null;
  } catch (_) {
    return null;
  }
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
