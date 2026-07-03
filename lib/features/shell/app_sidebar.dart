import 'dart:io';

import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/features/shell/account_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
    required this.onOpenAccount,
    required this.onLogout,
    this.account,
  });

  final NavSection selectedSection;
  final ValueChanged<NavSection> onSelectSection;
  final VoidCallback onOpenAccount;
  final VoidCallback onLogout;
  final AccountSummary? account;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F6),
        border: Border(right: BorderSide(color: Color(0xFFD7D7DB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!Platform.isWindows) ...[
            const DragToMoveArea(
              child: SizedBox(height: 16, width: double.infinity),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: Platform.isWindows ? EdgeInsetsGeometry.symmetric(horizontal: 18): const EdgeInsetsGeometry.only(left: 18, right: 18, top: 8),
            child: Text(
              'MirrorStages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          _SidebarItem(
            icon: CupertinoIcons.slider_horizontal_3,
            label: '控制面板',
            selected: selectedSection == NavSection.dashboard,
            onPressed: () => onSelectSection(NavSection.dashboard),
          ),
          _SidebarItem(
            icon: CupertinoIcons.gear,
            label: '设置',
            selected: selectedSection == NavSection.settings,
            onPressed: () => onSelectSection(NavSection.settings),
          ),
          const Spacer(),
          if (account != null)
            AccountMenu(
              account: account!,
              onOpenAccount: onOpenAccount,
              onLogout: onLogout,
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: CupertinoButton(
        alignment: Alignment.centerLeft,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE5E5EA) : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF3A3A3C)),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF1D1D1F),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
