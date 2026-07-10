import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thin client over go-gost's control API (base path `/config`).
///
/// `POST /config/<kind>` creates a named object and `PUT /config/<kind>/<name>`
/// updates one; either is an error against the wrong state, so [_upsert] picks
/// between them from the live config.
class GostApiClient {
  GostApiClient({required this._baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  /// True once the control API answers.
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(_baseUri.resolve('config'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// The full live configuration gost is running with.
  Future<Map<String, dynamic>> getConfig() async {
    final response = await _client.get(_baseUri.resolve('config'));
    _ensureOk(response);
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Creates or replaces the chain named [name].
  Future<void> upsertChain(String name, Map<String, dynamic> body) =>
      _upsert('chains', name, body);

  /// Creates or replaces the service named [name].
  Future<void> upsertService(String name, Map<String, dynamic> body) =>
      _upsert('services', name, body);

  /// Creates or replaces the bypass named [name].
  Future<void> upsertBypass(String name, Map<String, dynamic> body) =>
      _upsert('bypasses', name, body);

  Future<void> _upsert(
    String kind,
    String name,
    Map<String, dynamic> body,
  ) async {
    final exists = await _nameExists(kind, name);
    final payload = jsonEncode(body);
    const headers = {'Content-Type': 'application/json'};
    final response = exists
        ? await _client.put(
            _baseUri.resolve('config/$kind/$name'),
            headers: headers,
            body: payload,
          )
        : await _client.post(
            _baseUri.resolve('config/$kind'),
            headers: headers,
            body: payload,
          );
    _ensureOk(response);
  }

  Future<bool> _nameExists(String kind, String name) async {
    final config = await getConfig();
    final entries = config[kind];
    if (entries is! List) {
      return false;
    }
    return entries.any((entry) => entry is Map && entry['name'] == name);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode != 200) {
      throw http.ClientException(
        'gost API ${response.statusCode}: ${response.body}',
        response.request?.url,
      );
    }
  }

  void close() => _client.close();
}
