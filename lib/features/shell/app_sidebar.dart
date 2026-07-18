import 'dart:io';

import 'package:desktop/app/models/account_summary.dart';
import 'package:desktop/app/models/nav_section.dart';
import 'package:desktop/features/shell/account_menu.dart';
import 'package:desktop/features/shell/contact_support_item.dart';
import 'package:desktop/ui/app_colors.dart';
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
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.strongBorder)),
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
            padding: Platform.isWindows
                ? EdgeInsetsGeometry.symmetric(horizontal: 18)
                : const EdgeInsetsGeometry.only(left: 18, right: 18, top: 8),
            child: Text(
              'Mirrorstages',
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
          const ContactSupportItem(),
          const SizedBox(height: 6),
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
            color: selected ? AppColors.border : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.icon),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.label,
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
