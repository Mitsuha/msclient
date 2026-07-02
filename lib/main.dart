import 'package:desktop/app/app.dart';
import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

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
