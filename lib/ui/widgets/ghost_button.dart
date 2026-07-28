import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

/// A neutral outline button with a soft hover fill.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final filled = enabled && _hovered;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1,
          duration: const Duration(milliseconds: 80),
          // One value keeps fill, border, and label in sync.
          // Fade from a transparent tint to avoid a dark interpolation midpoint.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: filled ? 1 : 0),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            builder: (context, t, child) {
              final foreground = enabled
                  ? Color.lerp(AppColors.secondaryLabel, AppColors.label, t)!
                  : AppColors.placeholderText;
              return Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.secondaryButtonBackground.withValues(alpha: 0),
                    AppColors.secondaryButtonBackground,
                    t,
                  ),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: Color.lerp(
                      AppColors.border,
                      AppColors.strongBorder,
                      t,
                    )!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 12, color: foreground),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
