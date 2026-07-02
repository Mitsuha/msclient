import 'dart:convert';

import 'package:desktop/core/utils/jwt.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode(payload)}.signature';
}

void main() {
  group('decodeJwtPayload', () {
    test('decodes the payload segment without verifying the signature', () {
      final token = _fakeJwt({'account_sharing_member_id': 42});
      expect(decodeJwtPayload(token), {'account_sharing_member_id': 42});
    });

    test('returns null for a token without enough segments', () {
      expect(decodeJwtPayload('not-a-jwt'), isNull);
    });

    test('returns null for a malformed payload', () {
      expect(decodeJwtPayload('aGVhZGVy.%%%.sig'), isNull);
    });

    test('returns null when the payload is not a JSON object', () {
      final segment = base64Url.encode(utf8.encode('[1,2]'));
      expect(decodeJwtPayload('h.$segment.s'), isNull);
    });
  });
}
