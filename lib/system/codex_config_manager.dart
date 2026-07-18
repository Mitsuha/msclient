import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/app/models/tool_status.dart';
import 'package:desktop/core/utils/json_coercion.dart';
import 'package:desktop/core/utils/jwt.dart';
import 'package:desktop/system/codex_config_backup.dart';
import 'package:desktop/system/env_file.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/safe_fs.dart';
import 'package:desktop/system/tool_config_manager.dart';
import 'package:flutter/foundation.dart';

/// Reads and mutates the local Codex configuration under `~/.codex`
/// (auth.json, .env, config.toml), including backup/restore of the user's
/// pre-MirrorStages originals.
///
/// Each initialization concern is exposed as a check/write pair so the steps
/// can be verified and repaired individually:
///
/// | step            | check                    | write                  |
/// |-----------------|--------------------------|------------------------|
/// | proxy env       | [hasProxyEnv]            | [writeProxyEnv]        |
/// | auth            | [hasMirrorStagesAuth]    | [writeAuth]            |
/// | provider config | [hasCleanProviderConfig] | [clearProviderConfig]  |
class CodexConfigManager implements ToolConfigManager {
  CodexConfigManager({required this._home});

  final HomeDirectory _home;

  @override
  Future<String> directoryPath() async => '${await _home.resolve()}/.codex';

  @override
  Future<bool> isInstalled() async =>
      safeExists(Directory(await directoryPath()));

  @override
  Future<bool> hasRestorableBackup() async =>
      CodexConfigBackup(Directory(await directoryPath())).hasRestorableBackup();

  // --- ToolConfigManager proxy/backup lifecycle (delegates to the concrete
  // per-file methods below; the initializer steps use those directly) ---

  @override
  Future<bool> hasIssuedCredentials() => hasMirrorStagesAuth();

  @override
  Future<void> writeProxy(String proxyUrl) => writeProxyEnv(proxyUrl);

  @override
  Future<void> stripProxy() => removeProxyEnv();

  @override
  Future<void> clearProxy() => clearProxyEnv();

  /// Reports the Codex initialization state. Codex counts as initialized only
  /// when all three checks pass:
  ///
  /// 1. `.env` carries both `http_proxy` and `https_proxy` ([hasProxyEnv]);
  /// 2. `auth.json` parses and its `tokens.access_token` JWT payload carries
  ///    `account_sharing_member_id` and `user_id` ([hasMirrorStagesAuth]);
  /// 3. `config.toml` is absent or has no non-empty `provider` field
  ///    ([hasCleanProviderConfig]).
  ///
  /// Any failure along the way is treated as [ToolStatus.uninitialized] rather
  /// than surfaced as an error.
  @override
  Future<ToolStatus> readStatus() async {
    try {
      if (!await hasProxyEnv() || !await hasCleanProviderConfig()) {
        return const ToolStatus.uninitialized();
      }
      final authFile = File('${await directoryPath()}/auth.json');
      if (!await authFile.exists()) {
        return const ToolStatus.uninitialized();
      }
      final raw = await authFile.readAsString();
      if (!codexAuthGrantsMirrorStages(raw)) {
        return const ToolStatus.uninitialized();
      }
      return ToolStatus.initialized(_accountFrom(jsonDecode(raw)));
    } catch (_) {
      return const ToolStatus.uninitialized();
    }
  }

  /// Whether `.env` routes Codex through the local sing-box proxy: both
  /// `http_proxy` and `https_proxy` must match [AppConfig.singboxLocalProxyUrl].
  Future<bool> hasProxyEnv() async {
    try {
      final envFile = File('${await directoryPath()}/.env');
      if (!await envFile.exists()) {
        return false;
      }
      final env = parseEnvLines(await envFile.readAsLines());
      return env['http_proxy'] == AppConfig.singboxLocalProxyUrl &&
          env['https_proxy'] == AppConfig.singboxLocalProxyUrl;
    } catch (_) {
      return false;
    }
  }

  /// Points `.env`'s `http_proxy` / `https_proxy` at [proxyUrl], preserving
  /// any other entries the user keeps in the file.
  Future<void> writeProxyEnv(String proxyUrl) async {
    final envFile = File('${await directoryPath()}/.env');
    await envFile.parent.create(recursive: true);
    final env = await _readEnv(envFile);
    env['http_proxy'] = proxyUrl;
    env['https_proxy'] = proxyUrl;
    await envFile.writeAsString(serializeEnv(env));
  }

  /// Deletes `.env` so Codex stops routing through the MirrorStages proxy.
  /// A missing file is a no-op.
  Future<void> clearProxyEnv() async {
    final envFile = File('${await directoryPath()}/.env');
    if (await envFile.exists()) {
      await envFile.delete();
    }
  }

  /// Removes only `http_proxy` / `https_proxy` from `.env`, preserving any
  /// other entries the user keeps in the file. Deletes the file if it becomes
  /// empty. A missing file is a no-op.
  Future<void> removeProxyEnv() async {
    final envFile = File('${await directoryPath()}/.env');
    if (!await envFile.exists()) {
      return;
    }
    final env = await _readEnv(envFile)
      ..remove('http_proxy')
      ..remove('https_proxy');
    if (env.isEmpty) {
      await envFile.delete();
    } else {
      await envFile.writeAsString(serializeEnv(env));
    }
  }

  /// Whether `auth.json` carries a MirrorStages grant (see
  /// [codexAuthGrantsMirrorStages]).
  Future<bool> hasMirrorStagesAuth() async {
    try {
      final authFile = File('${await directoryPath()}/auth.json');
      if (!await authFile.exists()) {
        return false;
      }
      return codexAuthGrantsMirrorStages(await authFile.readAsString());
    } catch (_) {
      return false;
    }
  }

  /// Replaces `auth.json` with the MirrorStages [codexAuth].
  ///
  /// Does not back up the user's original — the backup is taken once, up front,
  /// by [preserveOriginals] during a full first-time initialization.
  Future<void> writeAuth(Map<String, dynamic> codexAuth) async {
    final codexDirectory = Directory(await directoryPath());
    await codexDirectory.create(recursive: true);
    await File(
      '${codexDirectory.path}/auth.json',
    ).writeAsString(_prettyJson(codexAuth));
  }

  /// Whether `config.toml` leaves Codex on the MirrorStages provider: the file
  /// is absent, or it has no non-empty `provider` field.
  Future<bool> hasCleanProviderConfig() async {
    try {
      final configFile = File('${await directoryPath()}/config.toml');
      if (!await configFile.exists()) {
        return true;
      }
      return !configTomlHasProvider(await configFile.readAsString());
    } catch (_) {
      return false;
    }
  }

  /// Removes `config.toml` so Codex falls back to the MirrorStages provider.
  ///
  /// Does not back up the user's original — the backup is taken once, up front,
  /// by [preserveOriginals] during a full first-time initialization.
  Future<void> clearProviderConfig() async {
    final configFile = File('${await directoryPath()}/config.toml');
    if (await configFile.exists()) {
      await configFile.delete();
    }
  }

  /// Snapshots the user's original `auth.json` / `config.toml` into
  /// `~/.codex/old_config` (each at most once) before MirrorStages overwrites
  /// them. Called only for a full first-time initialization, so no other entry
  /// point creates the backup.
  @override
  Future<void> preserveOriginals() async {
    await CodexConfigBackup(
      Directory(await directoryPath()),
    ).preserveOriginals();
  }

  /// Restores the user's original Codex configuration from
  /// `~/.codex/old_config`.
  ///
  /// Deletes the current auth.json / config.toml and moves the backed-up
  /// originals back into place. Throws [CodexConfigRestoreException] when
  /// there is no backup to restore.
  @override
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

  /// The signed-in account decoded from `auth.json`: display fields come from
  /// the `tokens.id_token` payload (falling back to the access token payload),
  /// the billing pack from the access token.
  ToolAccount _accountFrom(Object? auth) {
    final payload =
        _tokenPayloadFrom(auth, 'id_token') ??
        _tokenPayloadFrom(auth, 'access_token') ??
        const <String, dynamic>{};
    final openaiAuth = payload['https://api.openai.com/auth'];
    final planType = openaiAuth is Map
        ? openaiAuth['chatgpt_plan_type']?.toString()
        : null;
    return ToolAccount(
      email: payload['email']?.toString() ?? '',
      name: payload['name']?.toString() ?? '',
      planType: _planLabel(planType),
      userPackId: _userPackIdFrom(auth),
    );
  }

  /// Decodes the JWT payload of `tokens.<name>` from the decoded `auth.json`.
  Map<String, dynamic>? _tokenPayloadFrom(Object? auth, String name) {
    if (auth is! Map) {
      return null;
    }
    final tokens = auth['tokens'];
    if (tokens is! Map) {
      return null;
    }
    final token = tokens[name];
    if (token is! String || token.isEmpty) {
      return null;
    }
    return decodeJwtPayload(token);
  }

  /// Reads the access token's `user_pack_id` claim, or 0 when the token is
  /// absent, cannot be decoded, or carries no pack id (pay-as-you-go /
  /// 按量计费).
  int _userPackIdFrom(Object? auth) {
    final payload = _tokenPayloadFrom(auth, 'access_token');
    if (payload == null) {
      return 0;
    }
    return jsonInt(payload['user_pack_id']);
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

/// Whether a Codex `auth.json` string carries a MirrorStages grant: it parses
/// as JSON and its `tokens.access_token` JWT payload contains non-empty
/// `account_sharing_member_id` and `user_id` claims.
@visibleForTesting
bool codexAuthGrantsMirrorStages(String authJson) {
  try {
    final auth = jsonDecode(authJson);
    if (auth is! Map) {
      return false;
    }
    final tokens = auth['tokens'];
    if (tokens is! Map) {
      return false;
    }
    final accessToken = tokens['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      return false;
    }
    final payload = decodeJwtPayload(accessToken);
    if (payload == null) {
      return false;
    }
    return _hasClaim(payload, 'account_sharing_member_id') &&
        _hasClaim(payload, 'user_id');
  } catch (_) {
    return false;
  }
}

bool _hasClaim(Map<String, dynamic> payload, String name) {
  final value = payload[name];
  if (value == null) {
    return false;
  }
  return value is! String || value.isNotEmpty;
}

/// Whether a `config.toml` string carries a non-empty top-level `provider`
/// field, which means the user has pointed Codex away from MirrorStages.
@visibleForTesting
bool configTomlHasProvider(String content) {
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    if (line.substring(0, separator).trim() != 'provider') {
      continue;
    }
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.isNotEmpty) {
      return true;
    }
  }
  return false;
}

class CodexConfigRestoreException implements Exception {
  const CodexConfigRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
