import 'package:flutter/cupertino.dart';

import 'package:desktop/features/components/app_button.dart';
import 'package:desktop/features/components/section_card.dart';
import 'package:desktop/features/models/control_panel_models.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInstallRootCertificate,
    required this.onOpenAdminConsole,
    required this.onLogout,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onInstallRootCertificate;
  final VoidCallback onOpenAdminConsole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsToolbar(isWorking: isWorking, onRefresh: onRefresh),
          const SizedBox(height: 18),
          SectionCard(
            title: '根证书',
            child: _CertificateSettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onInstall: onInstallRootCertificate,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Codex 配置',
            child: _CodexSettings(snapshot: snapshot),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Claude 配置',
            child: _ClaudeSettings(snapshot: snapshot),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '账户设置',
            child: _AccountSettings(
              onOpenAdminConsole: onOpenAdminConsole,
              onLogout: onLogout,
            ),
          ),
          const Spacer(),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 520) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }
        return content;
      },
    );
  }
}

class _SettingsToolbar extends StatelessWidget {
  const _SettingsToolbar({required this.isWorking, required this.onRefresh});

  final bool isWorking;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '设置',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        if (isWorking) ...[
          const CupertinoActivityIndicator(radius: 9),
          const SizedBox(width: 10),
        ],
        AppButton(
          icon: CupertinoIcons.arrow_clockwise,
          label: '刷新',
          compact: true,
          color: const Color(0xFFE9E9ED),
          textColor: const Color(0xFF1D1D1F),
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}

class _CodexSettings extends StatelessWidget {
  const _CodexSettings({required this.snapshot});

  final ControlPanelSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final configuration = snapshot.localConfiguration;
    return Column(
      children: [
        _StatusRow(
          label: 'Codex 客户端',
          description: configuration.isCodexInstalled
              ? '已检测到本机 Codex 配置目录。'
              : '未检测到 Codex，请先完成 Codex 安装。',
          enabled: configuration.isCodexInstalled,
          enabledText: '已安装',
          disabledText: '未安装',
        ),
        if (configuration.isCodexInstalled) ...[
          const _Divider(),
          _StatusRow(
            label: 'MirrorStages 授权',
            description: snapshot.initialization.isInitialized
                ? 'Codex 已配置 MirrorStages 授权和代理环境。'
                : '需要初始化后才能使用 MirrorStages 账号运行 Codex。',
            enabled: snapshot.initialization.isInitialized,
            enabledText: '已初始化',
            disabledText: '未初始化',
          ),
        ],
      ],
    );
  }
}

class _ClaudeSettings extends StatelessWidget {
  const _ClaudeSettings({required this.snapshot});

  final ControlPanelSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final configuration = snapshot.localConfiguration;
    return _StatusRow(
      label: 'Claude 客户端',
      description: configuration.isClaudeInstalled
          ? '已检测到本机 Claude 配置目录。'
          : '未检测到 Claude，本功能不会影响 Codex 使用。',
      enabled: configuration.isClaudeInstalled,
      enabledText: '已安装',
      disabledText: '未安装',
    );
  }
}

class _CertificateSettings extends StatelessWidget {
  const _CertificateSettings({
    required this.snapshot,
    required this.isWorking,
    required this.onInstall,
  });

  final ControlPanelSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final certificate = snapshot.localConfiguration.rootCertificate;
    return _StatusRow(
      label: 'MirrorStages 根证书',
      description: certificate.isInstalled
          ? '本机已信任 MirrorStages 根证书。'
          : '安装后，本机 HTTPS 代理连接会被信任。',
      enabled: certificate.isInstalled,
      enabledText: '已安装',
      disabledText: '未安装',
      trailing: certificate.isInstalled
          ? null
          : AppButton(
              label: '安装',
              compact: true,
              color: const Color(0xFFFF9500),
              disabledColor: const Color(0xFFFFD59A),
              onPressed: isWorking ? null : onInstall,
            ),
    );
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings({
    required this.onOpenAdminConsole,
    required this.onLogout,
  });

  final VoidCallback onOpenAdminConsole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionRow(
          label: '管理账户与套餐',
          description: '打开 MirrorStages 后台查看余额、套餐和账户信息。',
          icon: CupertinoIcons.arrow_up_right_square,
          onPressed: onOpenAdminConsole,
        ),
        const _Divider(),
        _ActionRow(
          label: '退出登录',
          description: '清除当前客户端保存的登录状态。',
          icon: CupertinoIcons.square_arrow_right,
          destructive: true,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.description,
    required this.enabled,
    required this.enabledText,
    required this.disabledText,
    this.trailing,
  });

  final String label;
  final String description;
  final bool enabled;
  final String enabledText;
  final String disabledText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF34C759) : const Color(0xFF8E8E93);
    final text = enabled ? enabledText : disabledText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF3B30)
        : const Color(0xFF007AFF);
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14),
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE5E5EA))),
    );
  }
}
