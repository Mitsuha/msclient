import 'package:desktop/core/api/api_client.dart';

class ClaudeAuthApi {
  const ClaudeAuthApi(this._client);

  final ApiClient _client;

  /// Requests fresh Claude Code credentials billed against [userPackId], where
  /// 0 means pay-as-you-go (按量计费) and any other value is a subscription pack.
  Future<Map<String, dynamic>> createAuth({
    required String token,
    int userPackId = 0,
  }) {
    return _client.postJson(
      '/user/claude-auth',
      token: token,
      body: {'user_pack_id': userPackId},
    );
  }
}
