import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/features/dashboard/environment_status_presentation.dart';
import 'package:desktop/ui/app_colors.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:flutter/cupertino.dart';

class StatusAlert extends StatelessWidget {
  const StatusAlert({
    super.key,
    required this.snapshot,
    required this.isWorking,
    required this.onRefresh,
    required this.onInstallRootCertificate,
    this.errorMessage,
  });

  final AppSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onInstallRootCertificate;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final status = snapshot.isProxyRunning
        ? snapshot.environment
        : EnvironmentStatus.loading;
    final style = EnvironmentStatusPresentation.of(status);
    final message = status == EnvironmentStatus.loading
        ? style.defaultMessage
        : errorMessage ?? snapshot.message ?? style.defaultMessage;

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
                    color: AppColors.icon,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (status == EnvironmentStatus.conflict)
            AppButton(
              label: '重新检查',
              compact: true,
              color: AppColors.red,
              disabledColor: AppColors.redDisabledBright,
              onPressed: isWorking ? null : onRefresh,
            )
          else if (status == EnvironmentStatus.rootCertificateMissing)
            AppButton(
              label: '安装证书',
              compact: true,
              color: AppColors.orange,
              disabledColor: AppColors.orangeDisabled,
              onPressed: isWorking ? null : onInstallRootCertificate,
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
}
