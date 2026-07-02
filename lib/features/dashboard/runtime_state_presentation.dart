import 'package:desktop/app/models/app_snapshot.dart';
import 'package:flutter/cupertino.dart';

/// Copy and visual style for each [RuntimeState] shown in the status banner.
class RuntimeStatePresentation {
  const RuntimeStatePresentation({
    required this.title,
    required this.badge,
    required this.defaultMessage,
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
  });

  final String title;
  final String badge;
  final String defaultMessage;
  final IconData icon;
  final Color color;
  final Color background;
  final Color border;

  static RuntimeStatePresentation of(RuntimeState state) {
    return switch (state) {
      RuntimeState.conflict => const RuntimeStatePresentation(
        title: '有冲突软件正在运行',
        badge: '需要处理',
        defaultMessage: 'Mirrorstages 客户端不能和 CC-Switch 同时使用，请关闭 CC-Switch后重试。',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.rootCertificateMissing => const RuntimeStatePresentation(
        title: '需要安装根证书',
        badge: '待安装',
        defaultMessage: '需要安装 MirrorStages 根证书，用于本机 HTTPS 代理的受信任连接。',
        icon: CupertinoIcons.lock_shield_fill,
        color: Color(0xFFFF9500),
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE1A8),
      ),
      RuntimeState.uninitialized => const RuntimeStatePresentation(
        title: '未初始化',
        badge: '待初始化',
        defaultMessage: '本机 Codex 授权或代理环境变量尚未完成初始化。',
        icon: CupertinoIcons.info_circle_fill,
        color: Color(0xFFFF9500),
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE1A8),
      ),
      RuntimeState.running => const RuntimeStatePresentation(
        title: '正在运行',
        badge: '正常',
        defaultMessage: '配置完整，当前客户端可以正常工作。',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: Color(0xFF34C759),
        background: Color(0xFFF1FAF3),
        border: Color(0xFFCFEED5),
      ),
      RuntimeState.error => const RuntimeStatePresentation(
        title: '检测失败',
        badge: '错误',
        defaultMessage: '状态检测失败，请刷新后重试。',
        icon: CupertinoIcons.xmark_circle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.loading => const RuntimeStatePresentation(
        title: '正在检测',
        badge: '读取中',
        defaultMessage: '正在读取本机状态。',
        icon: CupertinoIcons.clock_fill,
        color: Color(0xFF007AFF),
        background: Color(0xFFF1F7FF),
        border: Color(0xFFCFE3FF),
      ),
    };
  }
}
