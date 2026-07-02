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
      tokenUsage: _int(json['token_usage']),
      tokenUsageUpdatedAt: _date(json['token_usage_update_at']),
      apiKeyCount: _int(json['api_key_count']),
    );
  }
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
