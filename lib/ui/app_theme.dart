import 'package:desktop/ui/app_colors.dart';
import 'package:flutter/cupertino.dart';

const windowsFontFamily = 'HarmonyOS Sans SC';

CupertinoThemeData buildAppTheme({required bool isWindows}) {
  return CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.blue,
    scaffoldBackgroundColor: AppColors.windowBackground,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        color: AppColors.label,
        fontSize: 14,
        fontFamily: isWindows ? windowsFontFamily : null,
        letterSpacing: 0,
      ),
    ),
  );
}
