import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/api/api_key_api.dart';
import 'package:desktop/data/models/api_key_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _listBody = '''
{
  "api_keys": [
    {
      "id": 5884,
      "key": "",
      "name": "deepseek",
      "pack_name": "Codex Plus",
      "last_use_at": "2026-07-26T17:31:02.904794+08:00"
    },
    {
      "id": 5871,
      "key": "",
      "name": "deepseek2",
      "providers": [
        {"id": 25, "display_name": "Deepseek（OpenAI 格式）"},
        {"id": 26, "display_name": "Kimi"}
      ],
      "last_use_at": "2026-07-25T16:56:13.464208+08:00",
      "created_at": "2026-07-25T16:21:53.256506+08:00"
    }
  ],
  "count": 13
}
''';

void main() {
  test('lists enabled keys for the whole account in one page', () async {
    late http.Request request;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.com/api'),
      httpClient: MockClient((sent) async {
        request = sent;
        return http.Response(_listBody, 200, headers: _jsonHeaders);
      }),
    );

    final list = await ApiKeyApi(client).listEnabled(token: 'token');

    expect(request.url.path, '/api/api-keys/');
    expect(request.url.queryParameters, {
      'page': '1',
      'size': '999',
      'status': '0',
    });
    expect(request.headers['Authorization'], 'Bearer token');
    expect(list.count, 13);
    expect(list.keys, hasLength(2));
  });

  test('parses a key bound to a pack', () async {
    final list = await _parse(_listBody);
    final key = list.keys.first;

    expect(key.id, 5884);
    expect(key.name, 'deepseek');
    expect(key.packName, 'Codex Plus');
    expect(key.providers, isEmpty);
    expect(key.enabled, isTrue);
    expect(
      key.lastUseAt?.toUtc(),
      DateTime.utc(2026, 7, 26, 9, 31, 2, 904, 794),
    );
  });

  test('parses a key with providers and no pack', () async {
    final list = await _parse(_listBody);
    final key = list.keys[1];

    expect(key.packName, isEmpty);
    expect(key.providers.map((provider) => provider.displayName), [
      'Deepseek（OpenAI 格式）',
      'Kimi',
    ]);
    expect(key.createdAt, isNotNull);
  });

  test(
    'treats a non-zero status as disabled and tolerates missing fields',
    () async {
      final list = await _parse('{"api_keys": [{"id": 1, "status": 1}]}');
      final key = list.keys.single;

      expect(key.enabled, isFalse);
      expect(key.name, isEmpty);
      expect(key.packName, isEmpty);
      expect(key.providers, isEmpty);
      expect(key.lastUseAt, isNull);
    },
  );
}

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Future<ApiKeyList> _parse(String body) {
  final client = ApiClient(
    baseUri: Uri.parse('https://example.com/api'),
    httpClient: MockClient(
      (_) async => http.Response(body, 200, headers: _jsonHeaders),
    ),
  );
  return ApiKeyApi(client).listEnabled(token: 'token');
}
