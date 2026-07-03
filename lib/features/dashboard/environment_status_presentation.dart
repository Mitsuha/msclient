import 'package:desktop/app/models/app_snapshot.dart';
import 'package:flutter/cupertino.dart';

/// Copy and visual style for each [EnvironmentStatus] shown in the status
/// banner.
class EnvironmentStatusPresentation {
  const EnvironmentStatusPresentation({
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

  static EnvironmentStatusPresentation of(EnvironmentStatus status) {
    return switch (status) {
      EnvironmentStatus.conflict => const EnvironmentStatusPresentation(
        title: '有冲突软件正在运行',
        badge: '需要处理',
        defaultMessage: 'Mirrorstages 客户端不能和 CC-Switch 同时使用，请关闭 CC-Switch后重试。',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      EnvironmentStatus.rootCertificateMissing =>
        const EnvironmentStatusPresentation(
          title: '需要安装根证书',
          badge: '待安装',
          defaultMessage: '需要安装 MirrorStages 根证书，用于本机 HTTPS 代理的受信任连接。',
          icon: CupertinoIcons.lock_shield_fill,
          color: Color(0xFFFF9500),
          background: Color(0xFFFFF8E8),
          border: Color(0xFFFFE1A8),
        ),
      EnvironmentStatus.ready => const EnvironmentStatusPresentation(
        title: '运行环境正常',
        badge: '正常',
        defaultMessage: '本机代理环境已就绪，可正常使用 MirrorStages。',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: Color(0xFF34C759),
        background: Color(0xFFF1FAF3),
        border: Color(0xFFCFEED5),
      ),
      EnvironmentStatus.error => const EnvironmentStatusPresentation(
        title: '检测失败',
        badge: '错误',
        defaultMessage: '状态检测失败，请刷新后重试。',
        icon: CupertinoIcons.xmark_circle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      EnvironmentStatus.loading => const EnvironmentStatusPresentation(
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
