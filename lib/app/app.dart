import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/features/shell/app_shell.dart';
import 'package:desktop/system/window_tray.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Root widget: theme, window lifecycle (close hides instead of quitting),
/// the Windows tray, the ⌘W shortcut, and the provider wiring. This is the
/// composition root — the only place in app/ allowed to import from features/.
class MirrorStagesApp extends StatefulWidget {
  const MirrorStagesApp({super.key});

  @override
  State<MirrorStagesApp> createState() => _MirrorStagesAppState();
}

class _MirrorStagesAppState extends State<MirrorStagesApp>
    with WindowListener, TrayListener {
  final WindowTray _tray = const WindowTray();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _tray.install();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _tray.remove();
    super.dispose();
  }

  @override
  void onWindowClose() {
    // Closing minimizes to the tray (Windows) / dock (macOS) rather than
    // quitting; the tray "退出" item or a forced destroy is the real exit.
    _hideWindow();
  }

  @override
  void onTrayIconMouseDown() {
    // Left-click the tray icon → bring the window back (Windows).
    _tray.showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    _tray.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case WindowTray.showItemKey:
        _tray.showWindow();
      case WindowTray.quitItemKey:
        _tray.quit();
    }
  }

  Future<void> _hideWindow() => _tray.hideWindow();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          AppViewModel(service: AppService.production())..bootstrap(),
      child: CupertinoApp(
        title: 'MirrorStages',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: Color(0xFF007AFF),
          scaffoldBackgroundColor: Color(0xFFF5F5F7),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              color: Color(0xFF1D1D1F),
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
        ),
        home: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyW, meta: true):
                _HideWindowIntent(),
          },
          child: Actions(
            actions: {
              _HideWindowIntent: CallbackAction<_HideWindowIntent>(
                onInvoke: (_) {
                  _hideWindow();
                  return null;
                },
              ),
            },
            child: const Focus(autofocus: true, child: AppShell()),
          ),
        ),
      ),
    );
  }
}

class _HideWindowIntent extends Intent {
  const _HideWindowIntent();
}
