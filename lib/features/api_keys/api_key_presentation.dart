import 'package:desktop/core/utils/formatters.dart';
import 'package:desktop/data/models/api_key_models.dart';
// For `String.characters`, so a monogram splits on grapheme clusters.
import 'package:flutter/widgets.dart';

/// Copy mappings for the API key list — kept out of the widgets so the rows
/// stay pure layout.

/// The pack a key bills against; a key without one is pay-as-you-go.
String packLabel(ApiKey apiKey) {
  return apiKey.packName.isEmpty ? '按量付费' : apiKey.packName;
}

/// Every bound provider, joined the way the server's own console shows them.
/// Empty when the key is not bound to a specific provider.
String providerLabel(ApiKey apiKey) {
  return apiKey.providers
      .map((provider) => provider.displayName)
      .where((name) => name.isNotEmpty)
      .join('、');
}

/// The secondary line: providers and last use, dropping whichever is missing.
String detailLine(ApiKey apiKey, {DateTime? now}) {
  final provider = providerLabel(apiKey);
  final lastUsed = lastUsedText(apiKey.lastUseAt, now: now);
  return provider.isEmpty ? lastUsed : '$provider · $lastUsed';
}

/// "上次使用 3 小时前" / "从未使用".
String lastUsedText(DateTime? lastUseAt, {DateTime? now}) {
  if (lastUseAt == null) {
    return '从未使用';
  }
  return '上次使用 ${formatRelativeTime(lastUseAt, now: now)}';
}

/// Badge monogram: the key's own initial, so every row stays distinguishable
/// even when several keys share a provider. Falls back to a bullet.
String apiKeyMonogram(ApiKey apiKey) {
  final trimmed = apiKey.name.trim();
  return trimmed.isEmpty ? '•' : trimmed.characters.first.toUpperCase();
}
