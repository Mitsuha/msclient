import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/system/home_directory.dart';

/// Resolves — and on first run downloads — the platform-specific `go-gost`
/// binary under `~/.mstages/bin`.
class GostBinary {
  GostBinary({
    required this._home,
    required this._logger,
    this.downloadBaseUrl = AppConfig.gostDownloadBaseUrl,
    HttpClient Function()? httpClientFactory,
    bool? isWindows,
    String? resolvedExecutable,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _isWindows = isWindows ?? Platform.isWindows,
       _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable;

  final HomeDirectory _home;
  final AppLogger _logger;
  final String downloadBaseUrl;
  final HttpClient Function() _httpClientFactory;
  final bool _isWindows;
  final String _resolvedExecutable;

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
    if (_isWindows) {
      final separator = _resolvedExecutable.lastIndexOf(RegExp(r'[/\\]'));
      if (separator < 0) {
        return 'gost.exe';
      }
      return '${_resolvedExecutable.substring(0, separator + 1)}gost.exe';
    }
    return '${await _binDirectoryPath()}/gost';
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
    if (_isWindows) {
      throw FileSystemException(
        'bundled gost.exe was not found; reinstall Mirrorstages',
        target.path,
      );
    }
    await _download('$downloadBaseUrl/$assetName', target);
    return target.path;
  }

  Future<void> _download(String url, File target) async {
    final temp = File('${target.path}.download');
    final uri = Uri.parse(url);
    final baseContext = <String, Object?>{
      'platform': Platform.operatingSystem,
      'asset': assetName,
      'url': url,
      'targetPath': target.path,
    };
    await _logger.info(
      'gost.download.started',
      'Starting gost download',
      context: baseContext,
    );

    try {
      await target.parent.create(recursive: true);
    } catch (error, stackTrace) {
      await _logWriteFailure(
        error,
        stackTrace,
        baseContext,
        stage: 'create_directory',
      );
      rethrow;
    }

    late HttpClient client;
    try {
      client = _httpClientFactory();
    } catch (error, stackTrace) {
      await _logger.error(
        'gost.download.http_failed',
        'Creating the gost download client failed',
        error: error.toString(),
        stackTrace: stackTrace,
        context: baseContext,
      );
      rethrow;
    }
    late HttpClientResponse response;
    try {
      try {
        final request = await client.getUrl(uri);
        response = await request.close();
      } catch (error, stackTrace) {
        await _logger.error(
          'gost.download.http_failed',
          'Gost download request failed',
          error: error.toString(),
          stackTrace: stackTrace,
          context: baseContext,
        );
        rethrow;
      }

      if (response.statusCode != HttpStatus.ok) {
        final error = HttpException(
          'downloading gost failed: HTTP ${response.statusCode}',
          uri: uri,
        );
        await _logger.error(
          'gost.download.http_failed',
          'Gost download returned a non-success status',
          error: error.toString(),
          stackTrace: StackTrace.current,
          context: {...baseContext, 'statusCode': response.statusCode},
        );
        throw error;
      }

      IOSink sink;
      try {
        sink = temp.openWrite();
      } catch (error, stackTrace) {
        await _logWriteFailure(
          error,
          stackTrace,
          baseContext,
          stage: 'write_temp',
        );
        rethrow;
      }

      try {
        await for (final chunk in response) {
          sink.add(chunk);
        }
      } catch (error, stackTrace) {
        await _closeIgnoringErrors(sink);
        await _logger.error(
          'gost.download.http_failed',
          'Gost response stream failed',
          error: error.toString(),
          stackTrace: stackTrace,
          context: baseContext,
        );
        rethrow;
      }

      try {
        await sink.flush();
        await sink.close();
      } catch (error, stackTrace) {
        await _closeIgnoringErrors(sink);
        await _logWriteFailure(
          error,
          stackTrace,
          baseContext,
          stage: 'write_temp',
        );
        rethrow;
      }
    } finally {
      client.close(force: true);
    }

    var stage = 'validate_size';
    try {
      // Guard against a truncated download leaving an unusable binary in place.
      if (await temp.length() < 1024 * 1024) {
        throw HttpException(
          'downloaded gost is too small to be valid',
          uri: uri,
        );
      }

      stage = 'rename';
      await temp.rename(target.path);
      if (!Platform.isWindows) {
        stage = 'chmod';
        final result = await Process.run('chmod', ['+x', target.path]);
        if (result.exitCode != 0) {
          throw ProcessException(
            'chmod',
            ['+x', target.path],
            result.stderr.toString(),
            result.exitCode,
          );
        }
      }
    } catch (error, stackTrace) {
      await _deleteIgnoringErrors(temp);
      await _logWriteFailure(error, stackTrace, baseContext, stage: stage);
      rethrow;
    }
  }

  Future<void> _logWriteFailure(
    Object error,
    StackTrace stackTrace,
    Map<String, Object?> baseContext, {
    required String stage,
  }) => _logger.error(
    'gost.download.write_failed',
    'Writing the gost binary failed',
    error: error.toString(),
    stackTrace: stackTrace,
    context: {...baseContext, 'stage': stage},
  );

  Future<void> _closeIgnoringErrors(IOSink sink) async {
    try {
      await sink.close();
    } catch (_) {}
  }

  Future<void> _deleteIgnoringErrors(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
