import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/system/codex_config_manager.dart';
import 'package:desktop/system/env_file.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHome extends HomeDirectory {
  _FakeHome(this.path);

  final String path;

  @override
  Future<String> resolve() async => path;
}

/// Builds an unsigned JWT whose payload is [payload].
String _jwt(Map<String, dynamic> payload) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64(payload)}.signature';
}

/// Builds an `auth.json` string whose access token payload is [claims].
String _authJson(Map<String, dynamic> claims) => jsonEncode({
  'tokens': {'access_token': _jwt(claims)},
});

void main() {
  group('CodexConfigManager.hasProxyEnv', () {
    late Directory home;
    late CodexConfigManager manager;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('codex-config-test-');
      manager = CodexConfigManager(home: _FakeHome(home.path));
      await Directory('${home.path}/.codex').create();
    });

    tearDown(() async {
      await home.delete(recursive: true);
    });

    test(
      'passes when both proxies point at the local sing-box proxy',
      () async {
        await File('${home.path}/.codex/.env').writeAsString(
          'http_proxy=${AppConfig.singboxLocalProxyUrl}\n'
          'https_proxy=${AppConfig.singboxLocalProxyUrl}\n',
        );

        expect(await manager.hasProxyEnv(), isTrue);
      },
    );

    test(
      'fails when non-empty proxies do not point at local sing-box',
      () async {
        await File('${home.path}/.codex/.env').writeAsString(
          'http_proxy=http://other-proxy:8080\n'
          'https_proxy=http://other-proxy:8080\n',
        );

        expect(await manager.hasProxyEnv(), isFalse);
      },
    );
  });

  group('CodexConfigManager.removeProxyEnv', () {
    late Directory home;
    late CodexConfigManager manager;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('codex-config-test-');
      manager = CodexConfigManager(home: _FakeHome(home.path));
      await Directory('${home.path}/.codex').create();
    });

    tearDown(() async {
      await home.delete(recursive: true);
    });

    test('removes proxy keys but preserves other entries', () async {
      final envFile = File('${home.path}/.codex/.env');
      await envFile.writeAsString(
        'http_proxy=${AppConfig.singboxLocalProxyUrl}\n'
        'https_proxy=${AppConfig.singboxLocalProxyUrl}\n'
        'foo=bar\n',
      );

      await manager.removeProxyEnv();

      final env = parseEnvLines(await envFile.readAsLines());
      expect(env.containsKey('http_proxy'), isFalse);
      expect(env.containsKey('https_proxy'), isFalse);
      expect(env['foo'], 'bar');
    });

    test('deletes the file when only proxy keys were present', () async {
      final envFile = File('${home.path}/.codex/.env');
      await envFile.writeAsString(
        'http_proxy=${AppConfig.singboxLocalProxyUrl}\n'
        'https_proxy=${AppConfig.singboxLocalProxyUrl}\n',
      );

      await manager.removeProxyEnv();

      expect(await envFile.exists(), isFalse);
    });

    test('is a no-op when the file is missing', () async {
      final envFile = File('${home.path}/.codex/.env');

      await manager.removeProxyEnv();

      expect(await envFile.exists(), isFalse);
    });
  });

  group('codexAuthGrantsMirrorStages', () {
    test('passes when both grant claims are present', () {
      expect(
        codexAuthGrantsMirrorStages(
          _authJson({'account_sharing_member_id': 42, 'user_id': 7}),
        ),
        isTrue,
      );
    });

    test('accepts non-empty string claims', () {
      expect(
        codexAuthGrantsMirrorStages(
          _authJson({'account_sharing_member_id': 'm-1', 'user_id': 'u-1'}),
        ),
        isTrue,
      );
    });

    test('fails when account_sharing_member_id is missing', () {
      expect(codexAuthGrantsMirrorStages(_authJson({'user_id': 7})), isFalse);
    });

    test('fails when user_id is missing', () {
      expect(
        codexAuthGrantsMirrorStages(
          _authJson({'account_sharing_member_id': 42}),
        ),
        isFalse,
      );
    });

    test('fails on empty string claims', () {
      expect(
        codexAuthGrantsMirrorStages(
          _authJson({'account_sharing_member_id': '', 'user_id': 'u-1'}),
        ),
        isFalse,
      );
    });

    test('fails when the access token is missing or not a JWT', () {
      expect(codexAuthGrantsMirrorStages(jsonEncode({'tokens': {}})), isFalse);
      expect(
        codexAuthGrantsMirrorStages(
          jsonEncode({
            'tokens': {'access_token': 'not-a-jwt'},
          }),
        ),
        isFalse,
      );
    });

    test('fails on malformed JSON', () {
      expect(codexAuthGrantsMirrorStages('{oops'), isFalse);
      expect(codexAuthGrantsMirrorStages('[]'), isFalse);
    });
  });

  group('configTomlHasProvider', () {
    test('detects a non-empty provider field', () {
      expect(configTomlHasProvider('provider = "openai"'), isTrue);
      expect(configTomlHasProvider("provider = 'custom'"), isTrue);
      expect(configTomlHasProvider('provider=custom'), isTrue);
    });

    test('treats a missing or empty provider as clean', () {
      expect(configTomlHasProvider(''), isFalse);
      expect(configTomlHasProvider('model = "gpt-5"'), isFalse);
      expect(configTomlHasProvider('provider = ""'), isFalse);
      expect(configTomlHasProvider('provider ='), isFalse);
    });

    test('ignores comments and unrelated keys', () {
      expect(configTomlHasProvider('# provider = "openai"'), isFalse);
      expect(configTomlHasProvider('model_provider = "openai"'), isFalse);
    });
  });
}
