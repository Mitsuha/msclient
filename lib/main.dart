import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:desktop/features/pages/control_panel_page.dart';
import 'package:desktop/features/services/control_panel_service.dart';
import 'package:desktop/features/view_models/control_panel_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  const windowOptions = WindowOptions(
    size: Size(980, 640),
    minimumSize: Size(860, 560),
    center: true,
    title: 'MirrorStages',
    backgroundColor: Color(0xFFF5F5F7),
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MirrorStagesApp());
}

class MirrorStagesApp extends StatefulWidget {
  const MirrorStagesApp({super.key});

  @override
  State<MirrorStagesApp> createState() => _MirrorStagesAppState();
}

class _MirrorStagesAppState extends State<MirrorStagesApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    _hideWindow();
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ControlPanelViewModel(service: ControlPanelService.local())
            ..bootstrap(),
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
            child: const Focus(autofocus: true, child: ControlPanelPage()),
          ),
        ),
      ),
    );
  }
}

class _HideWindowIntent extends Intent {
  const _HideWindowIntent();
}
