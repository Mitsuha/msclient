import 'package:flutter/cupertino.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.child,
    this.textColor = CupertinoColors.white,
    this.disabledColor = const Color(0xFFC7C7CC),
    this.compact = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? child;
  final Color textColor;
  final Color disabledColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 12.0 : 13.0;
    final iconSize = compact ? 13.0 : 14.0;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 7);

    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: CupertinoButton(
        minimumSize: Size(compact ? 28 : 76, compact ? 26 : 32),
        padding: padding,
        color: color,
        disabledColor: disabledColor,
        borderRadius: BorderRadius.circular(6),
        onPressed: onPressed,
        child:
            child ??
            _ButtonLabel(
              icon: icon,
              label: label,
              color: textColor,
              fontSize: fontSize,
              iconSize: iconSize,
            ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.color,
    required this.fontSize,
    required this.iconSize,
    this.icon,
  });

  final String label;
  final Color color;
  final double fontSize;
  final double iconSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) {
      return Text(
        label,
        style: TextStyle(color: color, fontSize: fontSize),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
      ],
    );
  }
}
