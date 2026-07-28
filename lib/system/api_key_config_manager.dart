import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/domain/api_keys/active_api_keys.dart';
import 'package:desktop/domain/api_keys/api_key_activation.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Writes and reads API-key-mode configs for local CLI tools.
/// Enabled tools get complete replacement files so account settings cannot
/// shadow the API key.
class ApiKeyConfigManager {
  const ApiKeyConfigManager({required this._home});

  final HomeDirectory _home;

  /// Writes [apiKey] into the configs of every tool [activation] enables.
  Future<void> apply({
    required String apiKey,
    required ApiKeyActivation activation,
  }) async {
    if (activation.codexEnabled) {
      await _writeCodex(apiKey, activation);
    }
    if (activation.claudeEnabled) {
      await _writeClaude(apiKey, activation);
    }
  }

  /// The key each tool's config currently carries, read straight off disk so
  /// an edit made outside the app is still reflected. A missing, malformed, or
  /// account-mode config simply reads as no key.
  Future<ActiveApiKeys> readActive() async {
    final home = await _home.resolve();
    return ActiveApiKeys(
      codexKey: await _readCodexKey(home),
      claudeKey: await _readClaudeKey(home),
    );
  }

  Future<String> _readCodexKey(String home) async {
    final auth = await _readJsonObject(
      File(path.join(home, '.codex', 'auth.json')),
    );
    return _stringAt(auth, 'OPENAI_API_KEY');
  }

  Future<String> _readClaudeKey(String home) async {
    final settings = await _readJsonObject(
      File(path.join(home, '.claude', 'settings.json')),
    );
    final env = settings['env'];
    return env is Map<String, dynamic>
        ? _stringAt(env, 'ANTHROPIC_AUTH_TOKEN')
        : '';
  }

  String _stringAt(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String ? value.trim() : '';
  }

  /// Parses [file] as a JSON object; anything unreadable is an empty map, since
  /// "we cannot tell which key this is" and "there is no key" lead to the same
  /// 启用 button.
  Future<Map<String, dynamic>> _readJsonObject(File file) async {
    try {
      if (!await file.exists()) {
        return const {};
      }
      final parsed = jsonDecode(await file.readAsString());
      return parsed is Map<String, dynamic> ? parsed : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _writeClaude(String apiKey, ApiKeyActivation activation) async {
    final directory = Directory(path.join(await _home.resolve(), '.claude'));
    await directory.create(recursive: true);
    await File(path.join(directory.path, 'settings.json')).writeAsString(
      buildClaudeSettings(apiKey: apiKey, activation: activation),
    );
  }

  Future<void> _writeCodex(String apiKey, ApiKeyActivation activation) async {
    final directory = Directory(path.join(await _home.resolve(), '.codex'));
    await directory.create(recursive: true);
    await File(
      path.join(directory.path, 'auth.json'),
    ).writeAsString(buildCodexAuth(apiKey));
    await File(
      path.join(directory.path, 'config.toml'),
    ).writeAsString(buildCodexConfigToml(activation.codexModel));
  }
}

/// Builds Claude's complete key-mode settings; blank models are omitted.
@visibleForTesting
String buildClaudeSettings({
  required String apiKey,
  required ApiKeyActivation activation,
}) {
  final env = <String, dynamic>{
    'ANTHROPIC_AUTH_TOKEN': apiKey,
    'ANTHROPIC_BASE_URL': AppConfig.anthropicBaseUrl,
  };
  void put(String key, String model) {
    if (model.trim().isNotEmpty) {
      env[key] = model.trim();
    }
  }

  put('ANTHROPIC_DEFAULT_OPUS_MODEL_NAME', activation.opusModel);
  put('ANTHROPIC_DEFAULT_SONNET_MODEL_NAME', activation.sonnetModel);
  put('ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME', activation.haikuModel);

  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({
    'env': env,
    'effortLevel': 'low',
    'enabledPlugins': {'gopls-lsp@claude-plugins-official': true},
    'model': 'opus',
  })}\n';
}

/// The whole `~/.codex/auth.json` for key mode.
@visibleForTesting
String buildCodexAuth(String apiKey) {
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert({'OPENAI_API_KEY': apiKey})}\n';
}

/// Builds Codex's complete key-mode config.
/// `model_provider` must match the `[model_providers.*]` table key.
@visibleForTesting
String buildCodexConfigToml(String model) {
  final resolved = model.trim().isEmpty
      ? ApiKeyActivation.defaultCodexModel
      : model.trim();
  return '''
model_provider = "${AppConfig.codexProviderKey}"
model = "$resolved"
model_reasoning_effort = "medium"
disable_response_storage = true

[model_providers.${AppConfig.codexProviderKey}]
name = "custom"
wire_api = "responses"
requires_openai_auth = true
base_url = "${AppConfig.openaiBaseUrl}"
''';
}
