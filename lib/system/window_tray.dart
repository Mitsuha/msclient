import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows system-tray integration.
///
/// On Windows there is no dock, so hiding the window on close would leave the
/// user no way back or out — the app could only be killed from Task Manager.
/// This adds a tray icon whose menu can re-show the window or truly quit, and
/// makes closing minimize to that tray. It is a no-op on macOS/Linux, where the
/// dock (and the existing hide-on-close behavior) already covers this.
class WindowTray {
  const WindowTray();

  /// Bundled tray icon (Windows wants an `.ico`).
  static const _iconPath = 'assets/tray/app_icon.ico';

  /// Context-menu item keys.
  static const showItemKey = 'show';
  static const quitItemKey = 'quit';

  /// Only Windows needs the tray; the other desktops fall back to their dock.
  bool get isSupported => Platform.isWindows;

  /// Registers the tray icon, tooltip, and context menu. Safe to call on any
  /// platform; does nothing where the tray is unsupported.
  Future<void> install() async {
    if (!isSupported) {
      return;
    }
    await trayManager.setIcon(_iconPath);
    await trayManager.setToolTip('MirrorStages');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: showItemKey, label: '显示主界面'),
          MenuItem.separator(),
          MenuItem(key: quitItemKey, label: '退出'),
        ],
      ),
    );
  }

  /// Removes the tray icon.
  Future<void> remove() async {
    if (!isSupported) {
      return;
    }
    await trayManager.destroy();
  }

  /// Pops up the tray context menu (Windows right-click).
  Future<void> popUpContextMenu() async {
    if (!isSupported) {
      return;
    }
    await trayManager.popUpContextMenu();
  }

  /// Brings the window back from the tray/dock and focuses it.
  Future<void> showWindow() async {
    if (Platform.isWindows) {
      await windowManager.setSkipTaskbar(false);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  /// Hides the window. On Windows it also drops off the taskbar so the tray
  /// icon becomes the single entry point back.
  Future<void> hideWindow() async {
    await windowManager.hide();
    if (Platform.isWindows) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  /// Really quits the app: lifts the prevent-close guard and destroys the
  /// window (the process exits with its only window gone).
  Future<void> quit() async {
    await remove();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
