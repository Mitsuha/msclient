import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop/system/claude_config_manager.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the URL-safe, unpadded base64 of [bytes] — the inverse of Go's
/// `base64.RawURLEncoding.EncodeToString`, matching how the access token stores
/// its content segment.
String _rawUrlB64(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Builds a credentials JSON string whose access token content decodes to
/// `userId|memberId|packId|` followed by 8 random padding bytes — the layout
/// produced by the server's `signClaudeAccessToken`.
String _credentials({
  String userId = 'uid',
  String memberId = 'member',
  String packId = 'pack',
  String prefix = 'sk-ant-oat01-',
}) {
  final raw = utf8.encode('$userId|$memberId|$packId|');
  // 8 bytes that are deliberately not valid UTF-8, to prove the parser reads
  // the pack id without decoding the padding tail.
  final padding = Uint8List.fromList(const [
    0xff,
    0xfe,
    0x80,
    0x00,
    1,
    2,
    3,
    4,
  ]);
  final content = _rawUrlB64([...raw, ...padding]);
  return jsonEncode({
    'claudeAiOauth': {'accessToken': '$prefix$content-abc123-def456'},
  });
}

/// Builds a `~/.claude.json` profile map with the given `oauthAccount` fields.
Map<String, dynamic> _profile({
  String? emailAddress,
  String? displayName,
  String? organizationRateLimitTier,
}) => {
  'oauthAccount': {
    'emailAddress': ?emailAddress,
    'displayName': ?displayName,
    'organizationRateLimitTier': ?organizationRateLimitTier,
  },
};

void main() {
  group('parseClaudeUserPackId', () {
    test('reads the pack id from the token, ignoring the padding tail', () {
      expect(parseClaudeUserPackId(_credentials(packId: '42')), 42);
    });

    test('is 0 for a non-numeric / pay-as-you-go pack id', () {
      expect(parseClaudeUserPackId(_credentials(packId: '0')), 0);
      expect(parseClaudeUserPackId(_credentials(packId: 'nan')), 0);
    });

    test('returns null when the token prefix is wrong', () {
      expect(
        parseClaudeUserPackId(_credentials(prefix: 'sk-ant-other-')),
        isNull,
      );
    });

    test('returns null for malformed JSON or missing oauth fields', () {
      expect(parseClaudeUserPackId('not json'), isNull);
      expect(parseClaudeUserPackId('{}'), isNull);
      expect(parseClaudeUserPackId(jsonEncode({'claudeAiOauth': {}})), isNull);
    });
  });

  group('claudeAccountFromProfile', () {
    test('sources email, display name, and plan from oauthAccount', () {
      final account = claudeAccountFromProfile(
        _profile(
          emailAddress: 'alex.chen@example.com',
          displayName: 'Alex Chen',
          organizationRateLimitTier: 'default_claude_max_20x',
        ),
        7,
      );

      expect(account.email, 'alex.chen@example.com');
      expect(account.name, 'Alex Chen');
      expect(account.planType, 'Max 20X');
      expect(account.userPackId, 7);
    });

    test('maps the known rate-limit tiers', () {
      String tierFor(String tier) => claudeAccountFromProfile(
        _profile(organizationRateLimitTier: tier),
        0,
      ).planType;

      expect(tierFor('default_claude_max_20x'), 'Max 20X');
      expect(tierFor('default_claude_max_5x'), 'Max 5X');
    });

    test('falls back to Pro for unknown or missing tiers', () {
      expect(
        claudeAccountFromProfile(
          _profile(organizationRateLimitTier: 'something_else'),
          0,
        ).planType,
        'Pro',
      );
      expect(claudeAccountFromProfile(_profile(), 0).planType, 'Pro');
    });

    test('falls back to the email local part when displayName is absent', () {
      final account = claudeAccountFromProfile(
        _profile(emailAddress: 'sam@example.com'),
        0,
      );

      expect(account.email, 'sam@example.com');
      expect(account.name, 'sam');
    });

    test('tolerates a missing oauthAccount', () {
      final account = claudeAccountFromProfile(const {}, 0);

      expect(account.email, '');
      expect(account.name, '');
      expect(account.planType, 'Pro');
    });
  });

  group('writeProxySettings', () {
    late Directory home;
    late ClaudeConfigManager config;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('claude-config-test');
      config = ClaudeConfigManager(home: _FakeHome(home.path));
    });

    tearDown(() => home.delete(recursive: true));

    File settingsFile() => File('${home.path}/.claude/settings.json');

    Future<Map<String, dynamic>> readSettings() async =>
        jsonDecode(await settingsFile().readAsString()) as Map<String, dynamic>;

    test('resets env to exactly the proxy entries', () async {
      await settingsFile().parent.create(recursive: true);
      await settingsFile().writeAsString(
        jsonEncode({
          'env': {
            'HTTPS_PROXY': 'https://old.example.com:5211',
            'ANTHROPIC_BASE_URL': 'https://old.example.com',
            'NO_PROXY': 'localhost',
          },
        }),
      );

      await config.writeProxySettings('http://127.0.0.1:18610');

      final settings = await readSettings();
      expect(settings['env'], {
        'HTTPS_PROXY': 'http://127.0.0.1:18610',
        'HTTP_PROXY': 'http://127.0.0.1:18610',
      });
    });

    test(
      'keeps every key outside env, pins defaults only when absent',
      () async {
        await settingsFile().parent.create(recursive: true);
        await settingsFile().writeAsString(
          jsonEncode({
            'theme': 'dark',
            'permissions': {
              'allow': ['Bash'],
            },
            'env': {'FOO': 'bar'},
          }),
        );

        await config.writeProxySettings('http://127.0.0.1:18610');

        final settings = await readSettings();
        expect(
          settings['theme'],
          'dark',
          reason: 'existing value is not pinned',
        );
        expect(settings['permissions'], {
          'allow': ['Bash'],
        });
        expect(
          settings['model'],
          'opus[1m]',
          reason: 'absent default is pinned',
        );
        expect((settings['env'] as Map).containsKey('FOO'), isFalse);
      },
    );

    test('creates the file from scratch when missing', () async {
      await config.writeProxySettings('http://127.0.0.1:18610');

      final settings = await readSettings();
      expect(settings['env'], {
        'HTTPS_PROXY': 'http://127.0.0.1:18610',
        'HTTP_PROXY': 'http://127.0.0.1:18610',
      });
      expect(settings['theme'], 'light');
      expect(settings['model'], 'opus[1m]');
    });
  });
}

class _FakeHome extends HomeDirectory {
  _FakeHome(this._path);

  final String _path;

  @override
  Future<String> resolve() async => _path;
}
