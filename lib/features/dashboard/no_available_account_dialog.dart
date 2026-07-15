import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// Shown when re-allocating an account fails because the pool is empty
/// (`api.error.no_available_account`). A soft macOS-style alert: an amber
/// warning glyph, a short explanation, and a single dismiss action.
Future<void> showNoAvailableAccountDialog(
  BuildContext context, {
  required String toolName,
}) {
  return showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _NoAvailableAccountDialog(toolName: toolName),
  );
}

class _NoAvailableAccountDialog extends StatelessWidget {
  const _NoAvailableAccountDialog({required this.toolName});

  final String toolName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: AppColors.barrier,
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _WarningGlyph(),
            const SizedBox(height: 16),
            const Text(
              '暂无可用账号',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$toolName 的账号池暂时没有可分配的账号，请稍后重试。'
              '若持续出现，请联系管理员。',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 22),
            _DismissButton(onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// The amber warning badge crowning the alert.
class _WarningGlyph extends StatelessWidget {
  const _WarningGlyph();

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.orangeTintBackground,
        ),
        child: const Icon(
          CupertinoIcons.person_crop_circle_badge_exclam,
          color: AppColors.orange,
          size: 30,
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '知道了',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
