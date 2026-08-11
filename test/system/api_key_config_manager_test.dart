import 'dart:convert';
import 'dart:io';

import 'package:desktop/domain/api_keys/api_key_activation.dart';
import 'package:desktop/system/api_key_config_manager.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const _activation = ApiKeyActivation.defaults();

/// Both tools on with the default models — [ApiKeyActivation.defaults] itself
/// starts opted out, so a write test has to switch them on.
const _bothTools = ApiKeyActivation(
  codexEnabled: true,
  codexModel: ApiKeyActivation.defaultCodexModel,
  claudeEnabled: true,
  opusModel: ApiKeyActivation.defaultOpusModel,
  sonnetModel: ApiKeyActivation.defaultSonnetModel,
  haikuModel: ApiKeyActivation.defaultHaikuModel,
);

void main() {
  group('claude settings.json', () {
    test('carries the key, the base url, and every model tier', () {
      final settings = jsonDecode(
        buildClaudeSettings(apiKey: 'sk-ms-123', activation: _activation),
      );

      expect(settings['env'], {
        'ANTHROPIC_AUTH_TOKEN': 'sk-ms-123',
        'ANTHROPIC_BASE_URL': 'https://api.mirrorstages.com/anthropic',
        'ANTHROPIC_DEFAULT_OPUS_MODEL_NAME': 'claude-opus-5',
        'ANTHROPIC_DEFAULT_SONNET_MODEL_NAME': 'claude-sonnet-4-5-20250929',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME': 'claude-haiku-4-5-20251001',
      });
      expect(settings['effortLevel'], 'low');
      expect(settings['model'], 'opus');
      expect(settings['enabledPlugins'], {
        'gopls-lsp@claude-plugins-official': true,
      });
    });

    test('omits the key of a model tier left blank', () {
      final settings = jsonDecode(
        buildClaudeSettings(
          apiKey: 'sk-ms-123',
          activation: const ApiKeyActivation(
            codexEnabled: false,
            codexModel: '',
            claudeEnabled: true,
            opusModel: 'claude-opus-5',
            sonnetModel: '  ',
            haikuModel: '',
          ),
        ),
      );
      final env = settings['env'] as Map<String, dynamic>;

      expect(env.containsKey('ANTHROPIC_DEFAULT_OPUS_MODEL_NAME'), isTrue);
      expect(env.containsKey('ANTHROPIC_DEFAULT_SONNET_MODEL_NAME'), isFalse);
      expect(env.containsKey('ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME'), isFalse);
    });
  });

  test('codex auth.json holds only the key', () {
    expect(jsonDecode(buildCodexAuth('sk-ms-123')), {
      'OPENAI_API_KEY': 'sk-ms-123',
    });
  });

  group('codex config.toml', () {
    test('points model_provider at the provider table key', () {
      final toml = buildCodexConfigToml('gpt-5.6-luna');

      expect(toml, contains('model_provider = "Mirrorstages"'));
      expect(toml, contains('[model_providers.Mirrorstages]'));
      expect(toml, contains('model = "gpt-5.6-luna"'));
      expect(toml, contains('model_reasoning_effort = "medium"'));
      expect(toml, contains('disable_response_storage = true'));
      expect(toml, contains('wire_api = "responses"'));
      expect(toml, contains('requires_openai_auth = true'));
      expect(
        toml,
        contains('base_url = "https://api.mirrorstages.com/openai/v1"'),
      );
    });

    test('falls back to the default model when the field is cleared', () {
      expect(buildCodexConfigToml('  '), contains('model = "gpt-5.6-luna"'));
    });

    test('keeps the user\'s other entries and drops the managed ones', () {
      final toml = buildCodexConfigToml(
        'gpt-5.6-luna',
        existing: '''
model = "gpt-4"
model_reasoning_effort = "high"
approval_policy = "never"

[model_providers.Mirrorstages]
base_url = "https://stale.example"

[tui]
theme = "dark"
''',
      );

      expect(toml, contains('approval_policy = "never"'));
      expect(toml, contains('[tui]'));
      expect(toml, contains('theme = "dark"'));
      expect(toml, isNot(contains('gpt-4')));
      expect(toml, isNot(contains('"high"')));
      expect(toml, isNot(contains('stale.example')));
      expect('[model_providers.Mirrorstages]'.allMatches(toml).length, 1);
      // Owned keys lead the file so they stay top-level.
      expect(toml.indexOf('model_provider'), lessThan(toml.indexOf('[tui]')));
    });
  });

  group('readActive', () {
    late Directory home;
    late ApiKeyConfigManager manager;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('api-key-config-test');
      manager = ApiKeyConfigManager(home: _FakeHome(home.path));
    });

    tearDown(() async {
      if (await home.exists()) {
        await home.delete(recursive: true);
      }
    });

    Future<void> write(String relativePath, String contents) async {
      final file = File(path.join(home.path, relativePath));
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
    }

    test('reads back exactly what apply wrote', () async {
      await manager.apply(apiKey: 'sk-ms-123', activation: _bothTools);

      final active = await manager.readActive();

      expect(active.codexKey, 'sk-ms-123');
      expect(active.claudeKey, 'sk-ms-123');
      expect(active.isInUse('sk-ms-123'), isTrue);
      expect(active.isInUse('sk-ms-other'), isFalse);
    });

    test('reports no key when the configs do not exist', () async {
      final active = await manager.readActive();

      expect(active.codexKey, isEmpty);
      expect(active.claudeKey, isEmpty);
      // An empty key must never match an empty config.
      expect(active.isInUse(''), isFalse);
    });

    test('reports only the tool that is on a key', () async {
      await manager.apply(
        apiKey: 'sk-ms-codex',
        activation: const ApiKeyActivation(
          codexEnabled: true,
          codexModel: 'gpt-5.6-luna',
          claudeEnabled: false,
          opusModel: '',
          sonnetModel: '',
          haikuModel: '',
        ),
      );

      final active = await manager.readActive();

      expect(active.codexKey, 'sk-ms-codex');
      expect(active.claudeKey, isEmpty);
      expect(active.isInUse('sk-ms-codex'), isTrue);
    });

    test('treats an account-mode claude settings.json as no key', () async {
      await write(
        path.join('.claude', 'settings.json'),
        jsonEncode({
          'env': {'HTTPS_PROXY': 'http://127.0.0.1:7890'},
        }),
      );

      expect((await manager.readActive()).claudeKey, isEmpty);
    });

    test('treats a malformed config as no key', () async {
      await write(path.join('.codex', 'auth.json'), 'not json at all');
      await write(path.join('.claude', 'settings.json'), '[]');

      final active = await manager.readActive();

      expect(active.codexKey, isEmpty);
      expect(active.claudeKey, isEmpty);
    });
  });
}

class _FakeHome extends HomeDirectory {
  _FakeHome(this._path);

  final String _path;

  @override
  Future<String> resolve() async => _path;
}
