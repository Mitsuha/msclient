import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:desktop/features/view_models/control_panel_view_model.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
    required this.onLogout,
  });

  final ControlPanelSection selectedSection;
  final ValueChanged<ControlPanelSection> onSelectSection;
  final VoidCallback onLogout;

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'MirrorStages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          _SidebarItem(
            icon: CupertinoIcons.slider_horizontal_3,
            label: '控制面板',
            selected: selectedSection == ControlPanelSection.dashboard,
            onPressed: () => onSelectSection(ControlPanelSection.dashboard),
          ),
          _SidebarItem(
            icon: CupertinoIcons.gear,
            label: '设置',
            selected: selectedSection == ControlPanelSection.settings,
            onPressed: () => onSelectSection(ControlPanelSection.settings),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsetsGeometry.only(bottom: 8),
            child: _SidebarAction(
              icon: CupertinoIcons.square_arrow_right,
              label: '退出登录',
              onPressed: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      alignment: Alignment.centerLeft,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6E6E73)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6E6E73), fontSize: 12),
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
    return CupertinoButton(
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
    );
  }
}
