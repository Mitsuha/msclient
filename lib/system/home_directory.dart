import 'dart:io';

import 'package:desktop/system/platform_channel.dart';
import 'package:flutter/services.dart';

/// Resolves the current user's home directory.
///
/// On macOS the native side is asked first via the platform channel; other
/// platforms (and the macOS fallback) use environment variables.
class HomeDirectory {
  HomeDirectory({this._channel = processInspectorChannel});

  final MethodChannel _channel;
  String? _cached;

  Future<String> resolve() async {
    return _cached ??= await _resolve();
  }

  Future<String> _resolve() async {
    if (Platform.isMacOS) {
      final nativeHome = await _channel.invokeMethod<String>(
        'userHomeDirectory',
      );
      if (nativeHome != null && nativeHome.isNotEmpty) {
        return nativeHome;
      }
    }

    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw FileSystemException(
        Platform.isWindows
            ? 'USERPROFILE is not available'
            : 'HOME is not available',
      );
    }
    return home;
  }
}
