import 'package:desktop/core/utils/json_coercion.dart';

enum UserPackStatus { active, exhausted, expired, unknown }

class UserPackProduct {
  const UserPackProduct({
    required this.id,
    required this.name,
    required this.balance,
    required this.grouping,
  });

  final int id;
  final String name;
  final num balance;
  final String grouping;

  factory UserPackProduct.fromJson(Map<String, dynamic> json) {
    return UserPackProduct(
      id: jsonInt(json['id']),
      name: json['name']?.toString() ?? '',
      balance: json['balance'] is num ? json['balance'] as num : 0,
      grouping: json['grouping']?.toString() ?? '',
    );
  }
}

class UserPack {
  const UserPack({
    required this.id,
    required this.product,
    required this.remainAmount,
    required this.status,
    required this.apiKeyCount,
    required this.lastUsedAt,
    required this.startAt,
    required this.expireAt,
    required this.createdAt,
    this.usagePercent,
  });

  final int id;
  final UserPackProduct product;
  final num remainAmount;
  final UserPackStatus status;
  final int apiKeyCount;
  final DateTime? lastUsedAt;
  final DateTime? startAt;
  final DateTime? expireAt;
  final DateTime? createdAt;
  final num? usagePercent;

  bool get isActive =>
      status == UserPackStatus.active || status == UserPackStatus.exhausted;

  factory UserPack.fromJson(Map<String, dynamic> json) {
    return UserPack(
      id: jsonInt(json['id']),
      product: UserPackProduct.fromJson(
        json['product'] as Map<String, dynamic>,
      ),
      remainAmount: json['remain_amount'] is num
          ? json['remain_amount'] as num
          : 0,
      status: _status(json['status']),
      apiKeyCount: jsonInt(json['api_key_count']),
      lastUsedAt: jsonDate(json['last_used_at']),
      startAt: jsonDate(json['start_at']),
      expireAt: jsonDate(json['expire_at']),
      createdAt: jsonDate(json['created_at']),
      usagePercent: json['usage_percent'] is num
          ? json['usage_percent'] as num
          : null,
    );
  }
}

class UserPackList {
  const UserPackList({required this.packs});

  final List<UserPack> packs;

  factory UserPackList.fromJson(Map<String, dynamic> json) {
    final packs = json['packs'];
    return UserPackList(
      packs: packs is List
          ? packs
                .whereType<Map<String, dynamic>>()
                .map(UserPack.fromJson)
                .toList()
          : const [],
    );
  }
}

UserPackStatus _status(Object? value) {
  return switch (jsonInt(value)) {
    0 => UserPackStatus.active,
    1 => UserPackStatus.exhausted,
    2 => UserPackStatus.expired,
    _ => UserPackStatus.unknown,
  };
}
