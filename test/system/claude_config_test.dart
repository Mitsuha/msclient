import 'dart:convert';

import 'package:desktop/system/claude_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the URL-safe, unpadded base64 of [value] — the inverse of Go's
/// `base64.RawURLEncoding.EncodeToString`, matching how the access token stores
/// its content segment.
String _rawUrlB64(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

/// Builds a credentials JSON string with an access token whose content segment
/// decodes to [fields], joined by `|`.
String _credentials({
  required List<String> fields,
  String? rateLimitTier,
  String prefix = 'sk-ant-oat01-',
}) {
  final content = _rawUrlB64(fields.join('|'));
  return jsonEncode({
    'claudeAiOauth': {
      'accessToken': '$prefix$content-abc123-def456',
      'rateLimitTier': ?rateLimitTier,
    },
  });
}

void main() {
  group('parseClaudeAccount', () {
    test('decodes the four fields and derives the username from the email', () {
      final account = parseClaudeAccount(
        _credentials(
          fields: ['uid', 'member', 'pack', 'alex.chen@example.com'],
          rateLimitTier: 'default_claude_max_20x',
        ),
      );

      expect(account, isNotNull);
      expect(account!.email, 'alex.chen@example.com');
      expect(account.name, 'alex.chen');
      expect(account.planType, 'Max 20X');
    });

    test('maps the known rate-limit tiers', () {
      String? tierFor(String tier) => parseClaudeAccount(
        _credentials(fields: ['a', 'b', 'c', 'u@e.com'], rateLimitTier: tier),
      )?.planType;

      expect(tierFor('default_claude_max_20x'), 'Max 20X');
      expect(tierFor('default_claude_max_5x'), 'Max 5X');
    });

    test('falls back to Pro for unknown or missing tiers', () {
      expect(
        parseClaudeAccount(
          _credentials(
            fields: ['a', 'b', 'c', 'u@e.com'],
            rateLimitTier: 'something_else',
          ),
        )?.planType,
        'Pro',
      );
      expect(
        parseClaudeAccount(
          _credentials(fields: ['a', 'b', 'c', 'u@e.com']),
        )?.planType,
        'Pro',
      );
    });

    test('returns null when the token prefix is wrong', () {
      expect(
        parseClaudeAccount(
          _credentials(
            fields: ['a', 'b', 'c', 'u@e.com'],
            prefix: 'sk-ant-other-',
          ),
        ),
        isNull,
      );
    });

    test('returns null when the decoded content is not exactly four fields', () {
      expect(
        parseClaudeAccount(_credentials(fields: ['a', 'b', 'u@e.com'])),
        isNull,
      );
      expect(
        parseClaudeAccount(
          _credentials(fields: ['a', 'b', 'c', 'd', 'u@e.com']),
        ),
        isNull,
      );
    });

    test('returns null for malformed JSON or missing oauth fields', () {
      expect(parseClaudeAccount('not json'), isNull);
      expect(parseClaudeAccount('{}'), isNull);
      expect(parseClaudeAccount(jsonEncode({'claudeAiOauth': {}})), isNull);
    });
  });
}
