import 'package:desktop/app/app.dart';
import 'package:desktop/ui/app_colors.dart';
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
    title: 'Mirrorstages',
    backgroundColor: AppColors.windowBackground,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MirrorStagesApp());
}
