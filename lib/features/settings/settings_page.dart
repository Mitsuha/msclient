import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/features/settings/error_banner.dart';
import 'package:desktop/features/settings/settings_rows.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:desktop/ui/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.errorMessage,
    required this.onRefresh,
    required this.onInstallRootCertificate,
    required this.onRestoreCodexConfig,
    required this.onRestoreClaudeConfig,
    required this.onOpenAdminConsole,
    required this.onLogout,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onInstallRootCertificate;
  final VoidCallback onRestoreCodexConfig;
  final VoidCallback onRestoreClaudeConfig;
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
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            ErrorBanner(message: errorMessage!),
          ],
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
            child: _CodexSettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onRestoreCodexConfig: onRestoreCodexConfig,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Claude 配置',
            child: _ClaudeSettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onRestoreClaudeConfig: onRestoreClaudeConfig,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '账户设置',
            child: _AccountSettings(
              onOpenAdminConsole: onOpenAdminConsole,
              onLogout: onLogout,
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(child: content);
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
  const _CodexSettings({
    required this.snapshot,
    required this.isWorking,
    required this.onRestoreCodexConfig,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRestoreCodexConfig;

  @override
  Widget build(BuildContext context) {
    final configuration = snapshot.localConfiguration;
    return Column(
      children: [
        StatusRow(
          label: 'Codex 客户端',
          description: configuration.isCodexInstalled
              ? '已检测到本机 Codex 配置目录。'
              : '未检测到 Codex，请先完成 Codex 安装。',
          enabled: configuration.isCodexInstalled,
          enabledText: '已安装',
          disabledText: '未安装',
        ),
        if (configuration.isCodexInstalled) ...[
          const RowDivider(),
          StatusRow(
            label: 'MirrorStages 授权',
            description: snapshot.codex.isInitialized
                ? 'Codex 已配置 MirrorStages 授权和代理环境。'
                : '需要初始化后才能使用 MirrorStages 账号运行 Codex。',
            enabled: snapshot.codex.isInitialized,
            enabledText: '已初始化',
            disabledText: '未初始化',
          ),
        ],
        const RowDivider(),
        StatusRow(
          label: '恢复原始配置',
          description: configuration.canRestoreCodexConfig
              ? '将恢复到初始化之前的配置。'
              : '暂无可恢复的备份，初始化后才会生成 old_config 备份。',
          enabled: true,
          enabledText: '',
          disabledText: '',
          trailing: AppButton(
            label: '恢复',
            compact: true,
            color: const Color(0xFFFF3B30),
            disabledColor: const Color(0xFFFFC3BF),
            onPressed: (isWorking || !configuration.canRestoreCodexConfig)
                ? null
                : () => _confirmRestore(context, onRestoreCodexConfig),
          ),
        ),
      ],
    );
  }
}

class _ClaudeSettings extends StatelessWidget {
  const _ClaudeSettings({
    required this.snapshot,
    required this.isWorking,
    required this.onRestoreClaudeConfig,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRestoreClaudeConfig;

  @override
  Widget build(BuildContext context) {
    final configuration = snapshot.localConfiguration;
    return Column(
      children: [
        StatusRow(
          label: 'Claude 客户端',
          description: configuration.isClaudeInstalled
              ? '已检测到本机 Claude 配置目录。'
              : '未检测到 Claude，本功能不会影响 Codex 使用。',
          enabled: configuration.isClaudeInstalled,
          enabledText: '已安装',
          disabledText: '未安装',
        ),
        const RowDivider(),
        StatusRow(
          label: 'MirrorStages 授权',
          description: snapshot.claude.isInitialized
              ? 'Claude Code 已配置 MirrorStages 授权凭据。'
              : '需要初始化后才能使用 MirrorStages 账号运行 Claude Code。',
          enabled: snapshot.claude.isInitialized,
          enabledText: '已初始化',
          disabledText: '未初始化',
        ),
        const RowDivider(),
        StatusRow(
          label: '恢复原始配置',
          description: configuration.canRestoreClaudeConfig
              ? '将恢复到初始化之前的登录凭据和 settings.json。'
              : '暂无可恢复的备份，初始化后才会生成 old_config 备份。',
          enabled: true,
          enabledText: '',
          disabledText: '',
          trailing: AppButton(
            label: '恢复',
            compact: true,
            color: const Color(0xFFFF3B30),
            disabledColor: const Color(0xFFFFC3BF),
            onPressed: (isWorking || !configuration.canRestoreClaudeConfig)
                ? null
                : () => _confirmRestore(context, onRestoreClaudeConfig),
          ),
        ),
      ],
    );
  }
}

/// Confirms a destructive "restore original config" action, invoking
/// [onConfirmed] only when the user accepts.
Future<void> _confirmRestore(
  BuildContext context,
  VoidCallback onConfirmed,
) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('恢复原始配置'),
      content: const Text('将恢复到初始化之前的配置，恢复后需要重新初始化才能运行'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('恢复'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirmed();
  }
}

class _CertificateSettings extends StatelessWidget {
  const _CertificateSettings({
    required this.snapshot,
    required this.isWorking,
    required this.onInstall,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final certificate = snapshot.localConfiguration.rootCertificate;
    return StatusRow(
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
        ActionRow(
          label: '管理账户与套餐',
          description: '打开 MirrorStages 后台查看余额、套餐和账户信息。',
          icon: CupertinoIcons.arrow_up_right_square,
          onPressed: onOpenAdminConsole,
        ),
        const RowDivider(),
        ActionRow(
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
