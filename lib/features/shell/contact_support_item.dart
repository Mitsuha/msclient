import 'dart:async';

import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

// Fixed panel size so the pop-up position can be clamped to the window before
// it is inserted into the overlay.
const double _panelWidth = 220;
const double _panelHeight = 250;
const double _edgeMargin = 8;

/// A sidebar entry that reveals the customer-support QR image in a floating
/// panel on hover. Styled to match the other sidebar items; the panel pops up
/// above the row and is clamped to stay within the window, not a modal dialog.
class ContactSupportItem extends StatefulWidget {
  const ContactSupportItem({super.key});

  @override
  State<ContactSupportItem> createState() => _ContactSupportItemState();
}

class _ContactSupportItemState extends State<ContactSupportItem> {
  OverlayEntry? _entry;
  Timer? _closeTimer;
  bool _hovered = false;

  bool get _isOpen => _entry != null;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  /// Keep the panel open while the pointer is over either the row or the panel,
  /// so crossing the small gap between them doesn't dismiss it.
  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 120), _close);
  }

  void _cancelClose() => _closeTimer?.cancel();

  void _open() {
    _cancelClose();
    if (_isOpen) return;

    final rowBox = context.findRenderObject() as RenderBox?;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlayState.context.findRenderObject() as RenderBox?;
    if (rowBox == null || overlayBox == null) return;

    final rowTopLeft = rowBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final windowSize = overlayBox.size;

    // Sit above the row, left edge aligned with it, then clamp into the window.
    final left = _clamp(
      rowTopLeft.dx,
      _edgeMargin,
      windowSize.width - _panelWidth - _edgeMargin,
    );
    final top = _clamp(
      rowTopLeft.dy - _edgeMargin - _panelHeight,
      _edgeMargin,
      windowSize.height - _panelHeight - _edgeMargin,
    );

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: MouseRegion(
          onEnter: (_) => _cancelClose(),
          onExit: (_) => _scheduleClose(),
          child: const _SupportPanel(),
        ),
      ),
    );
    overlayState.insert(entry);
    setState(() => _entry = entry);
  }

  /// [num.clamp] throws when the upper bound falls below the lower one (a window
  /// narrower/shorter than the panel); fall back to the lower bound instead.
  double _clamp(double value, double lower, double upper) {
    if (upper < lower) return lower;
    return value.clamp(lower, upper).toDouble();
  }

  void _close() {
    _closeTimer?.cancel();
    _entry?.remove();
    if (mounted) {
      setState(() => _entry = null);
    } else {
      _entry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        _open();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _scheduleClose();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (_isOpen || _hovered) ? AppColors.border : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.chat_bubble_2,
              size: 17,
              color: AppColors.icon,
            ),
            const SizedBox(width: 9),
            Text(
              '联系客服',
              style: TextStyle(
                color: AppColors.label,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportPanel extends StatelessWidget {
  const _SupportPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _panelWidth,
      height: _panelHeight,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.menuShadow,
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/images/customer.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          const Text(
            '性感客服，在线答疑',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}
