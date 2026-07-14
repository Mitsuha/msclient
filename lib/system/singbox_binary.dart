import 'dart:io';

import 'package:desktop/app/app_config.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/system/home_directory.dart';

/// Resolves — and when missing downloads — the platform-specific `sing-box`
/// binary. On Windows it lives next to the app executable (bundled by the MSI);
/// elsewhere under `~/.mstages/bin`.
class SingboxBinary {
  SingboxBinary({
    required this._home,
    required this._logger,
    this.downloadBaseUrl = AppConfig.singboxDownloadBaseUrl,
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

  /// The `sing-box-<os>` asset name for the current platform. macOS ships a
  /// single universal binary, so there is no arch suffix.
  String get assetName {
    if (Platform.isMacOS) {
      return 'sing-box-darwin';
    }
    if (Platform.isLinux) {
      return 'sing-box-linux';
    }
    if (Platform.isWindows) {
      return 'sing-box.exe';
    }
    throw UnsupportedError('sing-box is not available for this platform');
  }

  Future<String> _binDirectoryPath() async =>
      '${await _home.resolve()}/${AppConfig.dataDirectoryName}/bin';

  /// Absolute path the binary lives at. Windows is the only special case: the
  /// binary sits next to the app executable (bundled by the MSI); every other
  /// platform uses `~/.mstages/bin/sing-box`.
  Future<String> path() async {
    if (_isWindows) {
      final separator = _resolvedExecutable.lastIndexOf(RegExp(r'[/\\]'));
      if (separator < 0) {
        return 'sing-box.exe';
      }
      return '${_resolvedExecutable.substring(0, separator + 1)}sing-box.exe';
    }
    return '${await _binDirectoryPath()}/sing-box';
  }

  Future<bool> isInstalled() async => File(await path()).exists();

  /// The absolute path to the sing-box binary, downloading it when missing on
  /// any platform. On Windows the MSI normally ships it next to the executable,
  /// so the download only kicks in if that file is absent. The download lands on
  /// a temp file and is atomically renamed into place, so concurrent callers are
  /// safe.
  Future<String> ensureInstalled() async {
    final target = File(await path());
    if (await target.exists()) {
      return target.path;
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
      'singbox.download.started',
      'Starting sing-box download',
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
        'singbox.download.http_failed',
        'Creating the sing-box download client failed',
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
          'singbox.download.http_failed',
          'Sing-box download request failed',
          error: error.toString(),
          stackTrace: stackTrace,
          context: baseContext,
        );
        rethrow;
      }

      if (response.statusCode != HttpStatus.ok) {
        final error = HttpException(
          'downloading sing-box failed: HTTP ${response.statusCode}',
          uri: uri,
        );
        await _logger.error(
          'singbox.download.http_failed',
          'Sing-box download returned a non-success status',
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
          'singbox.download.http_failed',
          'Sing-box response stream failed',
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
          'downloaded sing-box is too small to be valid',
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
    'singbox.download.write_failed',
    'Writing the sing-box binary failed',
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
