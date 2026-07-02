import 'package:flutter/services.dart';

/// Channel served by the native runners; the name must match the one
/// registered in `macos/Runner/MainFlutterWindow.swift`.
const MethodChannel processInspectorChannel = MethodChannel(
  'com.mirrorstages.desktop/process_inspector',
);
