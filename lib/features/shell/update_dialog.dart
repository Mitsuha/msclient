import 'package:desktop/system/app_updater.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// The choice a user makes on the "update ready" dialog.
enum UpdateDialogAction { cancel, install }

/// Presents the macOS-style "update ready" dialog and resolves to the user's
/// choice, or null if the dialog is dismissed without one.
///
/// [context] must sit under the app's [Navigator] (pass the root navigator's
/// context when calling from outside the widget tree).
Future<UpdateDialogAction?> showUpdateDialog(
  BuildContext context,
  DownloadedUpdate update,
) {
  return showCupertinoDialog<UpdateDialogAction>(
    context: context,
    builder: (dialogContext) => _UpdateDialog(
      update: update,
      onCancel: () =>
          Navigator.of(dialogContext).pop(UpdateDialogAction.cancel),
      onInstall: () =>
          Navigator.of(dialogContext).pop(UpdateDialogAction.install),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({
    required this.update,
    required this.onCancel,
    required this.onInstall,
  });

  final DownloadedUpdate update;
  final VoidCallback onCancel;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoPopupSurface(
        isSurfacePainted: false,
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.strongBorder, width: 0.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.overlayCardShadow,
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                child: _buildDetails(),
              ),
              const SizedBox(
                height: 0.5,
                child: ColoredBox(color: AppColors.strongBorder),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      label: update.forced ? '退出' : '稍后提醒',
                      onPressed: onCancel,
                      destructive: update.forced,
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      label: '立即安装',
                      onPressed: onInstall,
                      primary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MirrorStages 更新已就绪',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.label,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          '新版本已经下载完成，可以立即安装。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.secondaryLabel,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        _VersionRow(label: '当前版本', value: update.currentVersion),
        const SizedBox(height: 8),
        _VersionRow(
          label: '最新版本',
          value: update.latestVersion,
          highlighted: true,
        ),
        if (update.forced) ...[
          const SizedBox(height: 18),
          const Text(
            '此版本为必要更新，旧版本已无法继续使用。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryLabel,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.tertiaryLabel,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.label,
            fontSize: 13,
            fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? CupertinoColors.white
        : destructive
        ? AppColors.red
        : AppColors.label;
    return CupertinoButton(
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      color: primary ? AppColors.blue : AppColors.neutralButtonBackground,
      borderRadius: BorderRadius.circular(7),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
