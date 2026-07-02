import 'package:desktop/core/api/api_client.dart';

class CodexAuthApi {
  const CodexAuthApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> createAuth({required String token}) {
    return _client.postJson('/user/codex-auth', token: token, hasBody: false);
  }
}
