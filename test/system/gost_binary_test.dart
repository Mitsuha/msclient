import 'dart:io';

import 'package:desktop/system/gost_binary.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recording_app_logger.dart';

class _TestHome extends HomeDirectory {
  _TestHome(this.path);

  final String path;

  @override
  Future<String> resolve() async => path;
}

void main() {
  late Directory tempHome;
  late HttpServer server;
  late RecordingAppLogger logger;

  setUp(() async {
    tempHome = await Directory.systemTemp.createTemp('gost_binary_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    logger = RecordingAppLogger();
  });

  tearDown(() async {
    await server.close(force: true);
    await tempHome.delete(recursive: true);
  });

  GostBinary createBinary({String? downloadBaseUrl}) => GostBinary(
    home: _TestHome(tempHome.path),
    logger: logger,
    downloadBaseUrl:
        downloadBaseUrl ?? 'http://${server.address.host}:${server.port}',
  );

  test('records download start and non-success HTTP response', () async {
    server.listen((request) async {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
    });

    await expectLater(
      createBinary().ensureInstalled(),
      throwsA(isA<HttpException>()),
    );

    expect(logger.entries.map((entry) => entry.event), [
      'gost.download.started',
      'gost.download.http_failed',
    ]);
    final failure = logger.entries.last;
    expect(failure.context['statusCode'], HttpStatus.serviceUnavailable);
    expect(failure.context['asset'], isNotEmpty);
    expect(failure.error, contains('downloading gost failed: HTTP 503'));
    expect(failure.stackTrace, isNotNull);
  });

  test('classifies an invalid downloaded file as a write failure', () async {
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..add(List<int>.filled(128, 1));
      await request.response.close();
    });

    await expectLater(
      createBinary().ensureInstalled(),
      throwsA(isA<HttpException>()),
    );

    expect(logger.entries.map((entry) => entry.event), [
      'gost.download.started',
      'gost.download.write_failed',
    ]);
    final failure = logger.entries.last;
    expect(failure.context['stage'], 'validate_size');
    expect(failure.error, contains('downloaded gost is too small'));
    expect(failure.stackTrace, isNotNull);
  });

  test('records target directory creation as a write failure', () async {
    await File('${tempHome.path}/.mstages').writeAsString('not a directory');

    await expectLater(
      createBinary().ensureInstalled(),
      throwsA(isA<FileSystemException>()),
    );

    expect(logger.entries.map((entry) => entry.event), [
      'gost.download.started',
      'gost.download.write_failed',
    ]);
    expect(logger.entries.last.context['stage'], 'create_directory');
  });
}
