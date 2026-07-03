import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/core/utils/json_coercion.dart';
import 'package:desktop/core/utils/jwt.dart';
import 'package:desktop/system/codex_config_backup.dart';
import 'package:desktop/system/env_file.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/tool_config_manager.dart';

/// Reads and mutates the local Codex configuration under `~/.codex`
/// (auth.json, .env, config.toml), including backup/restore of the user's
/// pre-MirrorStages originals.
class CodexConfigManager implements ToolConfigManager {
  CodexConfigManager({required this._home});

  final HomeDirectory _home;

  @override
  Future<String> directoryPath() async => '${await _home.resolve()}/.codex';

  @override
  Future<bool> isInstalled() async =>
      Directory(await directoryPath()).exists();

  Future<bool> hasRestorableBackup() async => CodexConfigBackup(
    Directory(await directoryPath()),
  ).hasRestorableBackup();

  /// Reads `auth.json`, decodes the account from its id token, and reports the
  /// Codex initialization state.
  ///
  /// Any failure along the way — the file is missing, the JSON is malformed,
  /// there is no id token, or the token's JWT cannot be decoded — is treated as
  /// [ToolStatus.uninitialized] rather than surfaced as an error.
  @override
  Future<ToolStatus> readStatus() async {
    try {
      final authFile = File('${await directoryPath()}/auth.json');
      final auth = jsonDecode(await authFile.readAsString());
      final token = _idTokenFrom(auth);
      if (token == null || token.isEmpty) {
        return const ToolStatus.uninitialized();
      }
      final payload = decodeJwtPayload(token);
      if (payload == null) {
        return const ToolStatus.uninitialized();
      }
      return ToolStatus.initialized(
        _accountFrom(payload, _userPackIdFrom(auth)),
      );
    } catch (_) {
      return const ToolStatus.uninitialized();
    }
  }

  /// Writes the MirrorStages auth.json and proxy env entries, removing any
  /// provider override in config.toml.
  Future<void> initialize({
    required Map<String, dynamic> codexAuth,
    required String proxyUrl,
  }) async {
    final codexDirectory = Directory(await directoryPath());
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
    final backup = CodexConfigBackup(Directory(await directoryPath()));
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

  /// Extracts `tokens.id_token` from the decoded `auth.json`.
  String? _idTokenFrom(Object? auth) {
    if (auth is! Map) {
      return null;
    }
    final tokens = auth['tokens'];
    if (tokens is! Map) {
      return null;
    }
    final token = tokens['id_token'];
    return token is String ? token : null;
  }

  /// Decodes `tokens.access_token` and reads its `user_pack_id` claim, or 0
  /// when the token is absent, cannot be decoded, or carries no pack id
  /// (pay-as-you-go / 按量计费).
  int _userPackIdFrom(Object? auth) {
    if (auth is! Map) {
      return 0;
    }
    final tokens = auth['tokens'];
    if (tokens is! Map) {
      return 0;
    }
    final accessToken = tokens['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      return 0;
    }
    final payload = decodeJwtPayload(accessToken);
    if (payload == null) {
      return 0;
    }
    return jsonInt(payload['user_pack_id']);
  }

  ToolAccount _accountFrom(Map<String, dynamic> payload, int userPackId) {
    final auth = payload['https://api.openai.com/auth'];
    final planType = auth is Map ? auth['chatgpt_plan_type']?.toString() : null;
    return ToolAccount(
      email: payload['email']?.toString() ?? '',
      name: payload['name']?.toString() ?? '',
      planType: _planLabel(planType),
      userPackId: userPackId,
    );
  }

  /// The display label for a Codex plan: capitalized, or `未知` when absent.
  String _planLabel(String? planType) {
    if (planType == null || planType.isEmpty) {
      return '未知';
    }
    return planType[0].toUpperCase() + planType.substring(1);
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
