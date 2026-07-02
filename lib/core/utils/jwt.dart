import 'dart:convert';

/// Decodes the payload segment of a JWT without verifying the signature.
/// Returns null when the token is malformed.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}
