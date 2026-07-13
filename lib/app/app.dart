import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/app_view_model.dart';
import 'package:desktop/features/shell/app_shell.dart';
import 'package:desktop/system/file_app_logger.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/window_tray.dart';
import 'package:desktop/ui/app_colors.dart';
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

  /// Held here (rather than created inside the provider) so the tray quit path
  /// can shut gost down before the window is destroyed.
  late final AppViewModel _viewModel;

  /// Catches every real app-exit path — macOS ⌘Q / dock "Quit" / app-menu
  /// Quit, not just the tray item — so gost is always stopped before the
  /// process dies. Window close/minimize does *not* come through here: it
  /// hides to the tray (see [onWindowClose]) and gost keeps running.
  late final AppLifecycleListener _lifecycleListener;
  Future<void>? _shutdown;

  @override
  void initState() {
    super.initState();
    final logger = FileAppLogger(home: HomeDirectory());
    _viewModel = AppViewModel(
      service: AppService.production(logger: logger),
      logger: logger,
    )..bootstrap();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequested,
    );
    windowManager.addListener(this);
    trayManager.addListener(this);
    _tray.install();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    _lifecycleListener.dispose();
    _tray.remove();
    _viewModel.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _handleExitRequested() async {
    await _shutdownApp();
    return AppExitResponse.exit;
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
        unawaited(_quit());
    }
  }

  Future<void> _quit() async {
    await _shutdownApp();
    await _tray.quit();
  }

  Future<void> _shutdownApp() => _shutdown ??= _viewModel.shutdown();

  Future<void> _hideWindow() => _tray.hideWindow();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppViewModel>.value(
      value: _viewModel,
      child: CupertinoApp(
        title: 'Mirrorstages',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: AppColors.blue,
          scaffoldBackgroundColor: AppColors.windowBackground,
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              color: AppColors.label,
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
            child: Focus(
              autofocus: true,
              child: AppShell(onExit: () => unawaited(_quit())),
            ),
          ),
        ),
      ),
    );
  }
}

class _HideWindowIntent extends Intent {
  const _HideWindowIntent();
}
