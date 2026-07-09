import 'dart:convert';

import 'package:desktop/system/codex_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an unsigned JWT whose payload is [payload].
String _jwt(Map<String, dynamic> payload) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64(payload)}.signature';
}

/// Builds an `auth.json` string whose access token payload is [claims].
String _authJson(Map<String, dynamic> claims) =>
    jsonEncode({
      'tokens': {'access_token': _jwt(claims)},
    });

void main() {
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
