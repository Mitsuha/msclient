import 'package:flutter/cupertino.dart';

import 'package:desktop/features/components/app_button.dart';
import 'package:desktop/features/models/control_panel_models.dart';

class StatusAlert extends StatelessWidget {
  const StatusAlert({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInitialize,
    required this.onInstallRootCertificate,
    this.errorMessage,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onInstallRootCertificate;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final style = _StatusStyle.fromState(snapshot.state);
    final message = errorMessage ?? snapshot.message ?? _messageFor(snapshot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3C),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (snapshot.state == RuntimeState.conflict)
            AppButton(
              label: '重新检查',
              compact: true,
              color: const Color(0xFFFF3B30),
              disabledColor: const Color(0xFFFFB3AD),
              onPressed: isWorking ? null : onRefresh,
            )
          else if (snapshot.state == RuntimeState.rootCertificateMissing)
            AppButton(
              label: '安装证书',
              compact: true,
              color: const Color(0xFFFF9500),
              disabledColor: const Color(0xFFFFD59A),
              onPressed: isWorking ? null : onInstallRootCertificate,
            )
          else if (snapshot.state == RuntimeState.uninitialized)
            AppButton(
              label: '初始化',
              compact: true,
              color: const Color(0xFFFF9500),
              disabledColor: const Color(0xFFFFD59A),
              onPressed: isWorking ? null : onInitialize,
            )
          else
            Text(
              style.badge,
              style: TextStyle(
                color: style.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  String _messageFor(ControlPanelSnapshot snapshot) {
    return switch (snapshot.state) {
      RuntimeState.conflict =>
        'Mirrorstages 客户端不能和 CC-Switch 同时使用，请关闭 CC-Switch后重试。',
      RuntimeState.rootCertificateMissing =>
        '需要安装 MirrorStages 根证书，用于本机 HTTPS 代理的受信任连接。',
      RuntimeState.uninitialized => '本机 Codex 授权或代理环境变量尚未完成初始化。',
      RuntimeState.running => '配置完整，当前客户端可以正常工作。',
      RuntimeState.error => '状态检测失败，请刷新后重试。',
      RuntimeState.loading => '正在读取本机状态。',
    };
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.title,
    required this.badge,
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
  });

  final String title;
  final String badge;
  final IconData icon;
  final Color color;
  final Color background;
  final Color border;

  static _StatusStyle fromState(RuntimeState state) {
    return switch (state) {
      RuntimeState.conflict => const _StatusStyle(
        title: '有冲突软件正在运行',
        badge: '需要处理',
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.rootCertificateMissing => const _StatusStyle(
        title: '需要安装根证书',
        badge: '待安装',
        icon: CupertinoIcons.lock_shield_fill,
        color: Color(0xFFFF9500),
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE1A8),
      ),
      RuntimeState.uninitialized => const _StatusStyle(
        title: '未初始化',
        badge: '待初始化',
        icon: CupertinoIcons.info_circle_fill,
        color: Color(0xFFFF9500),
        background: Color(0xFFFFF8E8),
        border: Color(0xFFFFE1A8),
      ),
      RuntimeState.running => const _StatusStyle(
        title: '正在运行',
        badge: '正常',
        icon: CupertinoIcons.check_mark_circled_solid,
        color: Color(0xFF34C759),
        background: Color(0xFFF1FAF3),
        border: Color(0xFFCFEED5),
      ),
      RuntimeState.error => const _StatusStyle(
        title: '检测失败',
        badge: '错误',
        icon: CupertinoIcons.xmark_circle_fill,
        color: Color(0xFFFF3B30),
        background: Color(0xFFFFF4F3),
        border: Color(0xFFFFD2CC),
      ),
      RuntimeState.loading => const _StatusStyle(
        title: '正在检测',
        badge: '读取中',
        icon: CupertinoIcons.clock_fill,
        color: Color(0xFF007AFF),
        background: Color(0xFFF1F7FF),
        border: Color(0xFFCFE3FF),
      ),
    };
  }
}
