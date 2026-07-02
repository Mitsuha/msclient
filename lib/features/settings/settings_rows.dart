import 'package:flutter/cupertino.dart';

/// A settings row with a label, one-line description, and either a
/// green/grey status badge or a custom [trailing] widget.
class StatusRow extends StatelessWidget {
  const StatusRow({
    super.key,
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

/// A tappable settings row that triggers an action, with an icon on the right.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
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

/// Hairline separator between rows inside a section card.
class RowDivider extends StatelessWidget {
  const RowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14),
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE5E5EA))),
    );
  }
}
