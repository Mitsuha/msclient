import 'dart:io';

import 'package:desktop/core/api/api_client.dart';

/// Issues MirrorStages credentials for a local AI CLI tool. Codex and Claude
/// Code share the exact request shape; only the endpoint differs.
class ToolAuthApi {
  const ToolAuthApi(this._client, this._endpoint);

  const ToolAuthApi.codex(ApiClient client) : this(client, '/user/codex-auth');

  const ToolAuthApi.claude(ApiClient client)
    : this(client, '/user/claude-auth');

  final ApiClient _client;
  final String _endpoint;

  /// Requests fresh credentials billed against [userPackId], where 0 means
  /// pay-as-you-go (按量计费) and any other value is a subscription pack.
  Future<Map<String, dynamic>> createAuth({
    required String token,
    int userPackId = 0,
  }) {
    return _client.postJson(
      _endpoint,
      token: token,
      body: {
        // Dart's own OS name (`macos` / `windows` / `linux`); the backend keys
        // on `macos`, not the Go CLI's `darwin`.
        'user_pack_id': userPackId,
        'client_type': Platform.operatingSystem,
      },
    );
  }
}
