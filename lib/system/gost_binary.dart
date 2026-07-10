import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter/foundation.dart';

/// Resolves — and on first run downloads — the platform-specific `go-gost`
/// binary under `~/.mstages/bin`.
class GostBinary {
  GostBinary({
    required this._home,
    this.downloadBaseUrl = AppConfig.gostDownloadBaseUrl,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final HomeDirectory _home;
  final String downloadBaseUrl;
  final HttpClient Function() _httpClientFactory;

  /// The `gost_<os>_<arch>` asset name for the current platform.
  String get assetName {
    if (Platform.isMacOS) {
      return _isArm64 ? 'gost_darwin_arm64' : 'gost_darwin_amd64';
    }
    if (Platform.isLinux) {
      return 'gost_linux_amd64';
    }
    if (Platform.isWindows) {
      return 'gost_windows_amd64.exe';
    }
    throw UnsupportedError('go-gost is not available for this platform');
  }

  /// `Platform.version` embeds the target ABI (e.g. `... on "macos_arm64"`).
  bool get _isArm64 => Platform.version.contains('arm64');

  Future<String> _binDirectoryPath() async =>
      '${await _home.resolve()}/${AppConfig.dataDirectoryName}/bin';

  /// Absolute path the binary lives at once installed.
  Future<String> path() async {
    final name = Platform.isWindows ? 'gost.exe' : 'gost';
    return '${await _binDirectoryPath()}/$name';
  }

  Future<bool> isInstalled() async => File(await path()).exists();

  /// The absolute path to the gost binary, downloading it on first run. The
  /// download lands on a temp file and is atomically renamed into place, so
  /// concurrent callers are safe.
  Future<String> ensureInstalled() async {
    final target = File(await path());
    if (await target.exists()) {
      return target.path;
    }
    await target.parent.create(recursive: true);
    await _download('$downloadBaseUrl/$assetName', target);
    return target.path;
  }

  Future<void> _download(String url, File target) async {
    final temp = File('${target.path}.download');
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'downloading gost failed: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      final sink = temp.openWrite();
      try {
        await response.pipe(sink);
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }

    // Guard against a truncated download leaving an unusable binary in place.
    if (await temp.length() < 1024 * 1024) {
      await temp.delete();
      throw HttpException(
        'downloaded gost is too small to be valid',
        uri: Uri.parse(url),
      );
    }

    await temp.rename(target.path);
    if (!Platform.isWindows) {
      final result = await Process.run('chmod', ['+x', target.path]);
      if (result.exitCode != 0) {
        debugPrint('chmod +x on gost failed: ${result.stderr}');
      }
    }
  }
}
