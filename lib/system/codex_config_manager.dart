import 'dart:convert';
import 'dart:io';

import 'package:desktop/core/utils/jwt.dart';
import 'package:desktop/system/codex_config_backup.dart';
import 'package:desktop/system/env_file.dart';
import 'package:desktop/system/home_directory.dart';

/// File-level state of `~/.codex` as it relates to MirrorStages.
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

/// Reads and mutates the local Codex configuration under `~/.codex`
/// (auth.json, .env, config.toml), including backup/restore of the user's
/// pre-MirrorStages originals.
class CodexConfigManager {
  CodexConfigManager({required this._home});

  final HomeDirectory _home;

  Future<String> codexDirectoryPath() async =>
      '${await _home.resolve()}/.codex';

  Future<String> claudeDirectoryPath() async =>
      '${await _home.resolve()}/.claude';

  Future<bool> isCodexInstalled() async =>
      Directory(await codexDirectoryPath()).exists();

  Future<bool> isClaudeInstalled() async =>
      Directory(await claudeDirectoryPath()).exists();

  Future<bool> hasRestorableBackup() async => CodexConfigBackup(
    Directory(await codexDirectoryPath()),
  ).hasRestorableBackup();

  Future<InitializationStatus> readInitializationStatus() async {
    final codexPath = await codexDirectoryPath();
    final authPath = '$codexPath/auth.json';
    final envPath = '$codexPath/.env';
    final configPath = '$codexPath/config.toml';
    final authFile = File(authPath);
    final envFile = File(envPath);
    final configFile = File(configPath);

    var hasAccessToken = false;
    var hasAccountSharingMemberId = false;
    if (await authFile.exists()) {
      final jsonText = await authFile.readAsString();
      final auth = jsonDecode(jsonText);
      final tokenValue = auth is Map<String, dynamic>
          ? auth['tokens'] is Map<String, dynamic>
                ? (auth['tokens'] as Map<String, dynamic>)['access_token']
                : null
          : null;
      final token = tokenValue is String ? tokenValue : null;
      hasAccessToken = token != null && token.isNotEmpty;
      final payload = hasAccessToken ? decodeJwtPayload(token) : null;
      hasAccountSharingMemberId =
          payload?.containsKey('account_sharing_member_id') ?? false;
    }

    final env = await _readEnv(envFile);
    final hasCodexProviderOverride = await _hasCodexProviderOverride(
      configFile,
    );
    return InitializationStatus(
      authPath: authPath,
      envPath: envPath,
      configPath: configPath,
      hasAuthFile: await authFile.exists(),
      hasAccessToken: hasAccessToken,
      hasAccountSharingMemberId: hasAccountSharingMemberId,
      hasHttpProxy: env['http_proxy']?.isNotEmpty == true,
      hasHttpsProxy: env['https_proxy']?.isNotEmpty == true,
      hasCodexProviderOverride: hasCodexProviderOverride,
    );
  }

  Future<InitializationStatus> emptyInitializationStatus() async {
    final codexPath = await codexDirectoryPath();
    return InitializationStatus(
      authPath: '$codexPath/auth.json',
      envPath: '$codexPath/.env',
      configPath: '$codexPath/config.toml',
      hasAuthFile: false,
      hasAccessToken: false,
      hasAccountSharingMemberId: false,
      hasHttpProxy: false,
      hasHttpsProxy: false,
      hasCodexProviderOverride: false,
    );
  }

  /// Writes the MirrorStages auth.json and proxy env entries, removing any
  /// provider override in config.toml.
  Future<void> initialize({
    required Map<String, dynamic> codexAuth,
    required String proxyUrl,
  }) async {
    final codexDirectory = Directory(await codexDirectoryPath());
    final authFile = File('${codexDirectory.path}/auth.json');
    final envFile = File('${codexDirectory.path}/.env');
    final configFile = File('${codexDirectory.path}/config.toml');
    await codexDirectory.create(recursive: true);

    // Move the user's original auth.json / config.toml into old_config before
    // we overwrite them, so the change can be rolled back via
    // restoreOriginals.
    await CodexConfigBackup(codexDirectory).preserveOriginals();

    await authFile.writeAsString(_prettyJson(codexAuth));

    final env = await _readEnv(envFile);
    env['http_proxy'] = proxyUrl;
    env['https_proxy'] = proxyUrl;
    await envFile.writeAsString(serializeEnv(env));

    // When a backup already existed, preserveOriginals left the live
    // config.toml in place; remove it so Codex falls back to the MirrorStages
    // provider.
    if (await configFile.exists()) {
      await configFile.delete();
    }
  }

  /// Restores the user's original Codex configuration from
  /// `~/.codex/old_config`.
  ///
  /// Deletes the current auth.json / config.toml and moves the backed-up
  /// originals back into place. Throws [CodexConfigRestoreException] when
  /// there is no backup to restore.
  Future<void> restoreOriginals() async {
    final backup = CodexConfigBackup(Directory(await codexDirectoryPath()));
    if (!await backup.hasRestorableBackup()) {
      throw const CodexConfigRestoreException('未找到可恢复的原始 Codex 配置。');
    }
    await backup.restore();
  }

  Future<Map<String, String>> _readEnv(File file) async {
    if (!await file.exists()) {
      return {};
    }
    return parseEnvLines(await file.readAsLines());
  }

  Future<bool> _hasCodexProviderOverride(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final text = await file.readAsString();
    return text.contains('base_url') && text.contains('model_provider');
  }

  String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(json)}\n';
  }
}

class CodexConfigRestoreException implements Exception {
  const CodexConfigRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
