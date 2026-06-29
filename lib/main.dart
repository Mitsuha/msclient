import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'package:desktop/features/control_panel/control_panel_screen.dart';
import 'package:desktop/features/control_panel/control_panel_service.dart';
import 'package:desktop/features/control_panel/control_panel_view_model.dart';

void main() {
  runApp(const MirrorStagesApp());
}

class MirrorStagesApp extends StatelessWidget {
  const MirrorStagesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ControlPanelViewModel(service: const ControlPanelService())..load(),
      child: const CupertinoApp(
        title: 'MirrorStages',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
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
        home: ControlPanelScreen(),
      ),
    );
  }
}
