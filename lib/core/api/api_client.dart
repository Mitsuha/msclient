import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
    Map<String, String>? query,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: _headers(token: token),
    );
    return _decode(response);
  }

  /// Like [getJson] but for endpoints whose body is a top-level JSON array.
  Future<List<dynamic>> getJsonList(
    String path, {
    String? token,
    Map<String, String>? query,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: _headers(token: token),
    );
    final body = response.body.isEmpty
        ? <dynamic>[]
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List) {
        return body;
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid response',
      );
    }

    final json = body is Map<String, dynamic>
        ? body
        : const <String, dynamic>{};
    throw ApiException(
      statusCode: response.statusCode,
      error: json['error']?.toString(),
      message: json['message']?.toString() ?? response.reasonPhrase,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    String? token,
    bool hasBody = true,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(token: token, hasBody: hasBody),
      body: hasBody ? jsonEncode(body ?? const <String, Object?>{}) : null,
    );
    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(
      path: '${baseUri.path}$normalizedPath',
      queryParameters: query,
    );
  }

  Map<String, String> _headers({String? token, bool hasBody = false}) {
    return {
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN',
      if (hasBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    final json = body is Map<String, dynamic>
        ? body
        : throw ApiException(
            statusCode: response.statusCode,
            message: 'Invalid response',
          );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    throw ApiException(
      statusCode: response.statusCode,
      error: json['error']?.toString(),
      message: json['message']?.toString() ?? response.reasonPhrase,
    );
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, this.error, this.message});

  final int statusCode;
  final String? error;
  final String? message;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() {
    final code = error == null ? '$statusCode' : '$statusCode $error';
    return message == null ? code : '$code: $message';
  }
}
