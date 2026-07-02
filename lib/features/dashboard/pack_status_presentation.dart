import 'package:desktop/data/models/pack_models.dart';
import 'package:flutter/cupertino.dart';

/// Copy and color for each [UserPackStatus] shown in the subscription card.
String packStatusText(UserPackStatus status) {
  return switch (status) {
    UserPackStatus.active => '已购买',
    UserPackStatus.exhausted => '已耗尽',
    UserPackStatus.expired => '已过期',
    UserPackStatus.unknown => '未知',
  };
}

Color packStatusColor(UserPackStatus status) {
  return switch (status) {
    UserPackStatus.active => const Color(0xFF34C759),
    UserPackStatus.exhausted => const Color(0xFFFF9500),
    UserPackStatus.expired => const Color(0xFF8E8E93),
    UserPackStatus.unknown => const Color(0xFF8E8E93),
  };
}
