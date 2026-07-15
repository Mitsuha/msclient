import 'dart:convert';
import 'dart:io';

import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/api/tool_auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'codex and claude auth requests include the current client type',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUri: Uri.parse('https://example.com'),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await ToolAuthApi.codex(client).createAuth(token: 'token');
      await ToolAuthApi.claude(
        client,
      ).createAuth(token: 'token', userPackId: 42);

      final expectedClientType = Platform.operatingSystem;
      expect(requests.map((request) => request.url.path), [
        '/user/codex-auth',
        '/user/claude-auth',
      ]);
      expect(jsonDecode(requests[0].body), {
        'user_pack_id': 0,
        'client_type': expectedClientType,
      });
      expect(jsonDecode(requests[1].body), {
        'user_pack_id': 42,
        'client_type': expectedClientType,
      });
    },
  );
}
