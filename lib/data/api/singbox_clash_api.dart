import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin client over sing-box's Clash API. Used for two things only: a health
/// probe (`GET /version`) and switching the selector's active outbound
/// (`PUT /proxies/<selector>`). The secret is sent as a Bearer token.
class SingboxClashApiClient {
  SingboxClashApiClient({
    required this._baseUri,
    required this._secret,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri _baseUri;
  final String _secret;
  final http.Client _client;

  Map<String, String> get _authHeader => {'Authorization': 'Bearer $_secret'};

  /// True once the Clash API answers.
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(_baseUri.resolve('version'), headers: _authHeader)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Switches [selector]'s active outbound to [outboundTag].
  Future<void> selectOutbound({
    required String selector,
    required String outboundTag,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('proxies/${Uri.encodeComponent(selector)}'),
      headers: {..._authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': outboundTag}),
    );
    // sing-box returns 204 No Content on a successful switch.
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw http.ClientException(
        'sing-box Clash API ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }
  }

  void close() => _client.close();
}
