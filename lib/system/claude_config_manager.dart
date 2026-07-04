import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/tool_config_manager.dart';
import 'package:flutter/foundation.dart';

/// The macOS Keychain generic-password item that Claude Code stores its
/// credentials under.
const String _keychainService = 'Claude Code-credentials';

/// Reads and writes the local Claude Code credentials.
///
/// On macOS these live in the login Keychain (item `Claude Code-credentials`);
/// on Windows/Linux they live in `~/.claude/.credentials.json`. The stored
/// value is the raw login info returned by `POST /user/claude-auth`.
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

  /// Sub-directory of `~/.claude` that holds the backed-up original config.
  static const _backupDirectoryName = 'old_config';
  static const _settingsFileName = 'settings.json';
  static const _credentialsFileName = '.credentials.json';

  /// Stores [claudeAuth] as the local Claude Code credentials, then routes
  /// Claude Code through the shared [proxyUrl] by rewriting `settings.json`.
  ///
  /// The user's original `settings.json` and credentials (the macOS Keychain
  /// item, or `.credentials.json` on Windows/Linux) are preserved into
  /// `~/.claude/old_config` first, so the change can be rolled back.
  Future<void> initialize({
    required Map<String, dynamic> claudeAuth,
    required String proxyUrl,
  }) async {
    final claudeDir = await directoryPath();
    await Directory(claudeDir).create(recursive: true);

    // Preserve the pristine originals before we overwrite anything. For
    // .credentials.json this must happen before the credential write below,
    // otherwise the backup would capture the MirrorStages file.
    await _preserveOriginals(claudeDir);

    final credentials = jsonEncode(claudeAuth);
    if (Platform.isMacOS) {
      await _writeToKeychain(credentials);
    } else {
      await _writeToFile(credentials);
    }

    await _writeSettings(claudeDir, proxyUrl);
  }

  /// Copies the user's original config into `~/.claude/old_config` once, before
  /// MirrorStages overwrites it, so the change can be rolled back.
  ///
  /// `settings.json` is always a file. Credentials are a file on Windows/Linux
  /// but live in the macOS Keychain — there we read the current Keychain item
  /// and snapshot it into `old_config/.credentials.json` so restore can write
  /// it back. A file is backed up at most once, so repeated initializations
  /// never clobber the pristine original with a MirrorStages-generated file.
  Future<void> _preserveOriginals(String claudeDir) async {
    final backupDir = Directory('$claudeDir/$_backupDirectoryName');

    await _backupFileOnce(
      live: File('$claudeDir/$_settingsFileName'),
      backup: File('${backupDir.path}/$_settingsFileName'),
      backupDir: backupDir,
    );

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

  /// Writes the MirrorStages `settings.json`: routes Claude Code traffic through
  /// the shared proxy and pins the theme/model.
  Future<void> _writeSettings(String claudeDir, String proxyUrl) async {
    final settings = <String, dynamic>{
      'env': <String, dynamic>{
        'HTTPS_PROXY': proxyUrl,
        'HTTP_PROXY': proxyUrl,
      },
      'theme': 'light',
      'model': 'opus[1m]',
    };
    const encoder = JsonEncoder.withIndent('  ');
    await File(
      '$claudeDir/$_settingsFileName',
    ).writeAsString('${encoder.convert(settings)}\n');
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

  /// Reads the stored credentials and reports the Claude Code initialization
  /// state. Any failure — the item/file is missing, the JSON is malformed, or
  /// the access token cannot be parsed — is treated as
  /// [ToolStatus.uninitialized] rather than surfaced as an error.
  @override
  Future<ToolStatus> readStatus() async {
    final credentials = await _readCredentials();
    if (credentials == null) {
      return const ToolStatus.uninitialized();
    }
    final account = parseClaudeAccount(credentials);
    return account == null
        ? const ToolStatus.uninitialized()
        : ToolStatus.initialized(account);
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

/// Parses the account out of a Claude Code credentials JSON string, or returns
/// null if the credentials cannot be interpreted as an initialized account.
///
/// The `claudeAiOauth.accessToken` is `sk-ant-oat01-<content>-<...>` where
/// `<content>` is the URL-safe, unpadded base64 of
/// `user_id|account_sharing_member_id|user_pack_id|account_email`.
@visibleForTesting
ToolAccount? parseClaudeAccount(String credentialsJson) {
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
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(content)));
    final fields = decoded.split('|');
    if (fields.length != 4) {
      return null;
    }

    final email = fields[3];
    return ToolAccount(
      email: email,
      name: email.split('@').first,
      planType: _planTypeFor(oauth['rateLimitTier']?.toString()),
      // fields[2] is user_pack_id ("0" for pay-as-you-go / 按量计费).
      userPackId: int.tryParse(fields[2]) ?? 0,
    );
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
