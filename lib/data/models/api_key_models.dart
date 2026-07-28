import 'package:desktop/core/utils/json_coercion.dart';

/// An upstream vendor an API key is bound to. A key may carry several.
class ApiKeyProvider {
  const ApiKeyProvider({required this.id, required this.displayName});

  final int id;
  final String displayName;

  factory ApiKeyProvider.fromJson(Map<String, dynamic> json) {
    return ApiKeyProvider(
      id: jsonInt(json['id']),
      displayName: json['display_name']?.toString() ?? '',
    );
  }
}

class ApiKey {
  const ApiKey({
    required this.id,
    required this.key,
    required this.name,
    required this.packName,
    required this.providers,
    required this.enabled,
    this.lastUseAt,
    this.createdAt,
  });

  final int id;

  /// The secret itself.
  final String key;

  final String name;

  /// The pack this key bills against; empty means pay-as-you-go.
  final String packName;

  final List<ApiKeyProvider> providers;

  /// Server `status`: 0 is enabled, anything else is not.
  final bool enabled;

  /// Null when the key has never been used.
  final DateTime? lastUseAt;

  final DateTime? createdAt;

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    final providers = json['providers'];
    return ApiKey(
      id: jsonInt(json['id']),
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      packName: json['pack_name']?.toString() ?? '',
      providers: providers is List
          ? providers
                .whereType<Map<String, dynamic>>()
                .map(ApiKeyProvider.fromJson)
                .toList()
          : const [],
      enabled: jsonInt(json['status']) == 0,
      lastUseAt: jsonDate(json['last_use_at']),
      createdAt: jsonDate(json['created_at']),
    );
  }

  ApiKey copyWith({bool? enabled}) {
    return ApiKey(
      id: id,
      key: key,
      name: name,
      packName: packName,
      providers: providers,
      enabled: enabled ?? this.enabled,
      lastUseAt: lastUseAt,
      createdAt: createdAt,
    );
  }
}

class ApiKeyList {
  const ApiKeyList({required this.keys, required this.count});

  final List<ApiKey> keys;

  /// Total on the server, which may exceed [keys] if the page size is hit.
  final int count;

  factory ApiKeyList.fromJson(Map<String, dynamic> json) {
    final keys = json['api_keys'];
    return ApiKeyList(
      keys: keys is List
          ? keys.whereType<Map<String, dynamic>>().map(ApiKey.fromJson).toList()
          : const [],
      count: jsonInt(json['count']),
    );
  }
}
