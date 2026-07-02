import 'package:desktop/app/models/app_snapshot.dart';
import 'package:desktop/features/dashboard/runtime_state_presentation.dart';
import 'package:desktop/ui/widgets/app_button.dart';
import 'package:flutter/cupertino.dart';

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

  final AppSnapshot snapshot;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onInitialize;
  final VoidCallback onInstallRootCertificate;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final style = RuntimeStatePresentation.of(snapshot.state);
    final message = errorMessage ?? snapshot.message ?? style.defaultMessage;

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
}
