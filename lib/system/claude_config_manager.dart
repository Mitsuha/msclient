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

  /// Stores [claudeAuth] as the local Claude Code credentials.
  Future<void> initialize({required Map<String, dynamic> claudeAuth}) async {
    final credentials = jsonEncode(claudeAuth);
    if (Platform.isMacOS) {
      await _writeToKeychain(credentials);
    } else {
      await _writeToFile(credentials);
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
    final result = await Process.run('/usr/bin/security', [
      'add-generic-password',
      '-a',
      _keychainAccount,
      '-s',
      _keychainService,
      '-w',
      credentials,
      // Update the item in place if it already exists, and allow the Claude
      // Code CLI to read it back without a per-access prompt.
      '-U',
      '-A',
    ]);
    if (result.exitCode != 0) {
      throw ClaudeConfigException(_processFailureDetails(result));
    }
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
