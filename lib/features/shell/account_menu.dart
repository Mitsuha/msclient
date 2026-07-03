import 'package:desktop/app/models/account_summary.dart';
import 'package:flutter/cupertino.dart';

/// The signed-in account tile at the bottom of the sidebar. Tapping it opens
/// a macOS-style popup menu with account actions.
class AccountMenu extends StatefulWidget {
  const AccountMenu({
    super.key,
    required this.account,
    required this.onOpenAccount,
    required this.onLogout,
  });

  final AccountSummary account;
  final VoidCallback onOpenAccount;
  final VoidCallback onLogout;

  @override
  State<AccountMenu> createState() => _AccountMenuState();
}

class _AccountMenuState extends State<AccountMenu> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _hovered = false;

  bool get _isOpen => _entry != null;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: CompositedTransformFollower(
              link: _link,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(14, -6),
              child: _MenuPanel(
                account: widget.account,
                onOpenAccount: () {
                  _close();
                  widget.onOpenAccount();
                },
                onLogout: () {
                  _close();
                  widget.onLogout();
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    setState(() => _entry = entry);
  }

  void _close() {
    _entry?.remove();
    if (mounted) {
      setState(() => _entry = null);
    } else {
      _entry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _toggle,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: (_isOpen || _hovered) ? const Color(0xFFE1E1E5) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _Avatar(name: widget.account.nickname, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.account.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.account.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: 13,
                  color: Color(0xFF6E6E73),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.account,
    required this.onOpenAccount,
    required this.onLogout,
  });

  final AccountSummary account;
  final VoidCallback onOpenAccount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _Avatar(name: account.nickname, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        account.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E73),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: CupertinoIcons.person,
            label: '账号',
            onPressed: onOpenAccount,
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: CupertinoIcons.square_arrow_right,
            label: '登出',
            onPressed: onLogout,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF2F2F7) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: const Color(0xFF1D1D1F)),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1D1D1F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: Color(0xFFE5E5EA)),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE1E1E5),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF3A3A3C),
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return '?';
    }
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(trimmed);
    if (letters != null) {
      return letters.substring(0, letters.length >= 2 ? 2 : 1).toUpperCase();
    }
    return String.fromCharCodes(trimmed.runes.take(1));
  }
}
