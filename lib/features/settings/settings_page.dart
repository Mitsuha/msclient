import 'package:desktop/app/initialization/tool_initializer.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/features/settings/error_banner.dart';
import 'package:desktop/features/settings/settings_rows.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:desktop/ui/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.errorMessage,
    required this.onRefresh,
    required this.onInstallRootCertificate,
    required this.onSelectProxy,
    required this.onApplyCodexInitStep,
    required this.onApplyClaudeInitStep,
    required this.onRestoreCodexConfig,
    required this.onRestoreClaudeConfig,
    required this.onClearConfig,
    required this.onOpenAdminConsole,
    required this.onLogout,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final String? errorMessage;
  final VoidCallback onRefresh;
  final VoidCallback onInstallRootCertificate;
  final ValueChanged<String> onSelectProxy;
  final ValueChanged<String> onApplyCodexInitStep;
  final ValueChanged<String> onApplyClaudeInitStep;
  final VoidCallback onRestoreCodexConfig;
  final VoidCallback onRestoreClaudeConfig;
  final VoidCallback onClearConfig;
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
            title: '代理节点',
            child: _ProxySettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onSelectProxy: onSelectProxy,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Codex 配置',
            child: _CodexSettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onApplyInitStep: onApplyCodexInitStep,
              onRestoreCodexConfig: onRestoreCodexConfig,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Claude 配置',
            child: _ClaudeSettings(
              snapshot: snapshot,
              isWorking: isWorking,
              onApplyInitStep: onApplyClaudeInitStep,
              onRestoreClaudeConfig: onRestoreClaudeConfig,
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: '清除配置',
            child: _ClearConfigSettings(
              isWorking: isWorking,
              onClearConfig: onClearConfig,
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
          color: AppColors.neutralButtonBackground,
          textColor: AppColors.label,
          onPressed: isWorking ? null : onRefresh,
        ),
      ],
    );
  }
}

class _ProxySettings extends StatelessWidget {
  const _ProxySettings({
    required this.snapshot,
    required this.isWorking,
    required this.onSelectProxy,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final ValueChanged<String> onSelectProxy;

  @override
  Widget build(BuildContext context) {
    final options = snapshot.proxyOptions;
    if (options.isEmpty) {
      return const StatusRow(
        label: '代理节点',
        description: '暂无可用节点，初始化时将使用默认代理地址。',
        enabled: false,
        enabledText: '',
        disabledText: '默认',
      );
    }

    // The saved url may have vanished from the server list; a null group value
    // simply leaves every segment unselected.
    final selectedUrl =
        options.any((option) => option.url == snapshot.selectedProxyUrl)
        ? snapshot.selectedProxyUrl
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务节点',
                  style: TextStyle(
                    color: AppColors.label,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '在连接慢时可尝试切换节点',
                  style: TextStyle(
                    color: AppColors.tertiaryLabel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AbsorbPointer(
            absorbing: isWorking,
            child: Opacity(
              opacity: isWorking ? 0.5 : 1,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: selectedUrl,
                children: {
                  for (final option in options)
                    option.url: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        option.name.isEmpty ? option.url : option.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.label,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                },
                onValueChanged: (url) {
                  if (url != null && url != snapshot.selectedProxyUrl) {
                    onSelectProxy(url);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The per-step check rows of a tool's initialization, each with a repair
/// button when the step's on-disk state does not pass.
class _InitStepRows extends StatelessWidget {
  const _InitStepRows({
    required this.steps,
    required this.isWorking,
    required this.onApplyStep,
  });

  final List<InitStepStatus> steps;
  final bool isWorking;
  final ValueChanged<String> onApplyStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final step in steps) ...[
          const RowDivider(),
          StatusRow(
            label: step.title,
            description: step.description,
            enabled: step.passed,
            enabledText: '已配置',
            disabledText: '未配置',
            trailing: step.passed
                ? null
                : AppButton(
                    label: '修复',
                    compact: true,
                    color: AppColors.orange,
                    disabledColor: AppColors.orangeDisabled,
                    onPressed: isWorking ? null : () => onApplyStep(step.id),
                  ),
          ),
        ],
      ],
    );
  }
}

class _CodexSettings extends StatelessWidget {
  const _CodexSettings({
    required this.snapshot,
    required this.isWorking,
    required this.onApplyInitStep,
    required this.onRestoreCodexConfig,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final ValueChanged<String> onApplyInitStep;
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
                ? 'Codex 已配置 MirrorStages 授权凭证'
                : '需要初始化后才能使用 MirrorStages 账号运行 Codex。',
            enabled: snapshot.codex.isInitialized,
            enabledText: '已初始化',
            disabledText: '未初始化',
          ),
          _InitStepRows(
            steps: snapshot.codexInitSteps,
            isWorking: isWorking,
            onApplyStep: onApplyInitStep,
          ),
        ],
        const RowDivider(),
        StatusRow(
          label: '恢复原始配置',
          description: configuration.canRestoreCodexConfig
              ? '将恢复到初始化之前的配置。'
              : '暂无可恢复的备份，初始化后才会生成备份。',
          enabled: true,
          enabledText: '',
          disabledText: '',
          trailing: AppButton(
            label: '恢复',
            compact: true,
            color: AppColors.red,
            disabledColor: AppColors.redDisabled,
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
    required this.onApplyInitStep,
    required this.onRestoreClaudeConfig,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final ValueChanged<String> onApplyInitStep;
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
              : '未检测到 Claude，请确认已经安装并且至少运行过一次。',
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
        if (configuration.isClaudeInstalled)
          _InitStepRows(
            steps: snapshot.claudeInitSteps,
            isWorking: isWorking,
            onApplyStep: onApplyInitStep,
          ),
        const RowDivider(),
        StatusRow(
          label: '恢复原始配置',
          description: configuration.canRestoreClaudeConfig
              ? '将恢复到初始化之前的登录凭据'
              : '暂无可恢复的备份，初始化后才会生成备份。',
          enabled: true,
          enabledText: '',
          disabledText: '',
          trailing: AppButton(
            label: '恢复',
            compact: true,
            color: AppColors.red,
            disabledColor: AppColors.redDisabled,
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
Future<void> _confirmRestore(BuildContext context, VoidCallback onConfirmed) {
  return _confirmDestructive(
    context,
    title: '恢复原始配置',
    content: '将恢复到初始化之前的配置，恢复后需要重新初始化才能运行',
    confirmLabel: '恢复',
    onConfirmed: onConfirmed,
  );
}

/// Shows a Cupertino confirm dialog for a destructive action, invoking
/// [onConfirmed] only when the user taps the (destructive) confirm button.
Future<void> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required VoidCallback onConfirmed,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirmed();
  }
}

/// The "清除配置" section: removes the MirrorStages proxy configuration from the
/// local tool configs (Claude Code `settings.json`, Codex `.env`).
class _ClearConfigSettings extends StatelessWidget {
  const _ClearConfigSettings({
    required this.isWorking,
    required this.onClearConfig,
  });

  final bool isWorking;
  final VoidCallback onClearConfig;

  @override
  Widget build(BuildContext context) {
    return StatusRow(
      label: '清除代理配置',
      description: '如果遇到无法使用第三方 API 的情况，可以尝试清除代理配置',
      enabled: true,
      enabledText: '',
      disabledText: '',
      trailing: AppButton(
        label: '清除',
        compact: true,
        color: AppColors.red,
        disabledColor: AppColors.redDisabled,
        onPressed: isWorking
            ? null
            : () => _confirmDestructive(
                context,
                title: '清除代理配置',
                content:
                    '将移除Codex 和 Claude Code 里和 MirrorStages 相关的配置，清除后需要重新初始化才能使用。',
                confirmLabel: '清除',
                onConfirmed: onClearConfig,
              ),
      ),
    );
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
          ? '已经安装 MirrorStages 证书，可以正常使用。'
          : '需要安装 Mirrorstages 的证书才能正常使用。',
      enabled: certificate.isInstalled,
      enabledText: '已安装',
      disabledText: '未安装',
      trailing: certificate.isInstalled
          ? null
          : AppButton(
              label: '安装',
              compact: true,
              color: AppColors.orange,
              disabledColor: AppColors.orangeDisabled,
              onPressed: isWorking ? null : onInstall,
            ),
    );
  }
}

class _AccountSettings extends StatefulWidget {
  const _AccountSettings({
    required this.onOpenAdminConsole,
    required this.onLogout,
  });

  final VoidCallback onOpenAdminConsole;
  final VoidCallback onLogout;

  @override
  State<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<_AccountSettings> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ActionRow(
          label: '管理账户与套餐',
          description: '打开 MirrorStages 后台查看余额、套餐和账户信息。',
          icon: CupertinoIcons.arrow_up_right_square,
          onPressed: widget.onOpenAdminConsole,
        ),
        const RowDivider(),
        ActionRow(
          label: '退出登录',
          description: '清除当前客户端保存的登录状态。',
          icon: CupertinoIcons.square_arrow_right,
          destructive: true,
          onPressed: widget.onLogout,
        ),
        const RowDivider(),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final packageInfo = snapshot.data;
            final version = packageInfo == null
                ? '读取中…'
                : packageInfo.buildNumber.isEmpty
                ? packageInfo.version
                : '${packageInfo.version}+${packageInfo.buildNumber}';

            return StatusRow(
              label: '版本号',
              description: '当前客户端版本。',
              enabled: true,
              enabledText: version,
              disabledText: '',
            );
          },
        ),
      ],
    );
  }
}
