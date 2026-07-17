import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/ui/app_colors.dart';
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
        color: AppColors.red,
        background: AppColors.redTintBackground,
        border: AppColors.redTintBorder,
      ),
      EnvironmentStatus.rootCertificateMissing =>
        const EnvironmentStatusPresentation(
          title: '需要安装根证书',
          badge: '待安装',
          defaultMessage: '需要安装 MirrorStages 根证书，用于本机 HTTPS 代理的受信任连接。',
          icon: CupertinoIcons.lock_shield_fill,
          color: AppColors.orange,
          background: AppColors.orangeTintBackground,
          border: AppColors.orangeTintBorder,
        ),
      EnvironmentStatus.ready => const EnvironmentStatusPresentation(
        title: '运行环境正常',
        badge: '正常',
        defaultMessage: 'MirrorStages 环境已配置完毕，可启动 Codex\\Claude Code。',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: AppColors.green,
        background: AppColors.greenTintBackground,
        border: AppColors.greenTintBorder,
      ),
      EnvironmentStatus.error => const EnvironmentStatusPresentation(
        title: '检测失败',
        badge: '错误',
        defaultMessage: '状态检测失败，请刷新后重试。',
        icon: CupertinoIcons.xmark_circle_fill,
        color: AppColors.red,
        background: AppColors.redTintBackground,
        border: AppColors.redTintBorder,
      ),
      EnvironmentStatus.loading => const EnvironmentStatusPresentation(
        title: '启动中',
        badge: '启动中',
        defaultMessage: '正在连接本地服务。',
        icon: CupertinoIcons.clock_fill,
        color: AppColors.blue,
        background: AppColors.infoTintBackground,
        border: AppColors.infoTintBorder,
      ),
    };
  }
}
