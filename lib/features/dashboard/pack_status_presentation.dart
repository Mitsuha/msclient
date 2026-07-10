import 'package:desktop/data/models/pack_models.dart';
import 'package:desktop/ui/app_colors.dart';
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
    UserPackStatus.active => AppColors.green,
    UserPackStatus.exhausted => AppColors.orange,
    UserPackStatus.expired => AppColors.tertiaryLabel,
    UserPackStatus.unknown => AppColors.tertiaryLabel,
  };
}
