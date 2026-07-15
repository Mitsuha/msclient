import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class DownloadedUpdate {
  const DownloadedUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.forced,
    required this.installerPath,
  });

  final String currentVersion;
  final String latestVersion;
  final bool forced;
  final String installerPath;
}

/// Periodically checks for, downloads, and announces desktop app updates.
class AppUpdater {
  AppUpdater(
    this._logger,
    this._onUpdateReady, {
    HomeDirectory? home,
    http.Client? client,
  }) : _home = home ?? HomeDirectory(),
       _client = client ?? http.Client();

  static final Uri _manifestUri = Uri.parse(
    'https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/version.json',
  );
  static const _checkInterval = Duration(minutes: 1);

  final AppLogger _logger;
  final Future<void> Function(DownloadedUpdate update) _onUpdateReady;
  final HomeDirectory _home;
  final http.Client _client;

  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;
  String? _announcedVersion;

  void start() {
    if (_timer != null || _disposed) return;
    unawaited(checkNow());
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(checkNow()));
  }

  Future<void> checkNow() async {
    if (_checking || _disposed) return;
    _checking = true;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await _client.get(_manifestUri);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update manifest returned HTTP ${response.statusCode}',
          uri: _manifestUri,
        );
      }

      final manifest = _UpdateManifest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      final currentVersion = packageInfo.buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+${packageInfo.buildNumber}';
      if (!isNewerVersion(manifest.version, currentVersion) ||
          _announcedVersion == manifest.version) {
        return;
      }

      final downloadUri = manifest.downloadUriForCurrentPlatform();
      final installer = await _download(downloadUri);
      if (_disposed) return;

      await _onUpdateReady(
        DownloadedUpdate(
          currentVersion: currentVersion,
          latestVersion: manifest.version,
          forced: manifest.forced,
          installerPath: installer.path,
        ),
      );
      _announcedVersion = manifest.version;
    } catch (error, stackTrace) {
      await _logger.error(
        'app.update.failed',
        'Failed to check or download an app update',
        error: error.toString(),
        stackTrace: stackTrace,
      );
    } finally {
      _checking = false;
    }
  }

  Future<File> _download(Uri uri) async {
    final home = await _home.resolve();
    final directory = Directory('$home/.mstages/update');
    await directory.create(recursive: true);

    final fileName = uri.pathSegments.isEmpty
        ? _defaultInstallerName
        : uri.pathSegments.last;
    final target = File('${directory.path}/$fileName');
    final temporary = File('${target.path}.download');

    final request = http.Request('GET', uri);
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Update download returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    try {
      await response.stream.pipe(temporary.openWrite());
      if (await target.exists()) await target.delete();
      return temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  String get _defaultInstallerName {
    if (Platform.isMacOS) return 'mirrorstages.dmg';
    if (Platform.isWindows) return 'mirrorstages.msi';
    return 'mirrorstages.deb';
  }

  Future<void> runInstaller(String path) async {
    if (Platform.isMacOS) {
      await Process.start('open', [path], mode: ProcessStartMode.detached);
      return;
    }
    if (Platform.isWindows) {
      await Process.start('msiexec.exe', [
        '/i',
        path,
      ], mode: ProcessStartMode.detached);
      return;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      return;
    }
    throw UnsupportedError('Updates are not supported on this platform');
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _client.close();
  }
}

class _UpdateManifest {
  const _UpdateManifest({
    required this.version,
    required this.forced,
    required this.authDownload,
  });

  factory _UpdateManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final forced = json['forced'];
    final authDownload = json['auth_download'];
    if (version is! String ||
        version.trim().isEmpty ||
        forced is! bool ||
        authDownload is! Map<String, dynamic>) {
      throw const FormatException('Invalid update manifest');
    }
    return _UpdateManifest(
      version: version.trim(),
      forced: forced,
      authDownload: authDownload,
    );
  }

  final String version;
  final bool forced;
  final Map<String, dynamic> authDownload;

  Uri downloadUriForCurrentPlatform() {
    final key = Platform.isMacOS
        ? 'darwin'
        : Platform.isWindows
        ? 'windows'
        : Platform.isLinux
        ? 'linux'
        : null;
    final value = key == null ? null : authDownload[key];
    if (value is! String || value.isEmpty) {
      throw UnsupportedError('No update download for this platform');
    }
    return Uri.parse(value);
  }
}

/// Compares the numeric parts of app versions, including the build number.
bool isNewerVersion(String candidate, String current) {
  List<int> parts(String value) => RegExp(
    r'\d+',
  ).allMatches(value).map((match) => int.parse(match.group(0)!)).toList();

  final candidateParts = parts(candidate);
  final currentParts = parts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final candidatePart = index < candidateParts.length
        ? candidateParts[index]
        : 0;
    final currentPart = index < currentParts.length ? currentParts[index] : 0;
    if (candidatePart != currentPart) return candidatePart > currentPart;
  }
  return false;
}
