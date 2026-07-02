import 'package:desktop/core/utils/json_coercion.dart';

class DashboardOverview {
  const DashboardOverview({
    required this.balance,
    required this.tokenUsage,
    required this.tokenUsageUpdatedAt,
    required this.apiKeyCount,
  });

  final num balance;
  final int tokenUsage;
  final DateTime? tokenUsageUpdatedAt;
  final int apiKeyCount;

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      balance: json['balance'] is num ? json['balance'] as num : 0,
      tokenUsage: jsonInt(json['token_usage']),
      tokenUsageUpdatedAt: jsonDate(json['token_usage_update_at']),
      apiKeyCount: jsonInt(json['api_key_count']),
    );
  }
}
