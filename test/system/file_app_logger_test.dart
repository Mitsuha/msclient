import 'dart:convert';
import 'dart:io';

import 'package:desktop/system/file_app_logger.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestHome extends HomeDirectory {
  _TestHome(this.path);

  final String path;

  @override
  Future<String> resolve() async => path;
}

void main() {
  late Directory tempHome;
  late DateTime now;
  late FileAppLogger logger;

  setUp(() async {
    tempHome = await Directory.systemTemp.createTemp('file_app_logger_test_');
    now = DateTime(2026, 7, 13, 9, 8, 7, 6);
    logger = FileAppLogger(home: _TestHome(tempHome.path), now: () => now);
  });

  tearDown(() async {
    await tempHome.delete(recursive: true);
  });

  test('writes a structured JSON line to the local-date file', () async {
    await logger.info(
      'gost.download.started',
      'Starting gost download',
      context: const {'asset': 'gost_darwin_arm64'},
    );

    final file = File('${tempHome.path}/.mstages/logs/app-2026-07-13.log');
    final lines = await file.readAsLines();
    final entry = jsonDecode(lines.single) as Map<String, dynamic>;

    expect(entry['timestamp'], '2026-07-13T09:08:07.006');
    expect(entry['level'], 'info');
    expect(entry['event'], 'gost.download.started');
    expect(entry['message'], 'Starting gost download');
    expect(entry['context'], {'asset': 'gost_darwin_arm64'});
    expect(entry.containsKey('error'), isFalse);
    expect(entry.containsKey('stackTrace'), isFalse);
  });

  test('serializes concurrent writes into complete lines', () async {
    await Future.wait([
      for (var index = 0; index < 20; index++)
        logger.info('test.event', 'entry $index', context: {'index': index}),
    ]);

    final lines = await File(
      '${tempHome.path}/.mstages/logs/app-2026-07-13.log',
    ).readAsLines();

    expect(lines, hasLength(20));
    expect(
      lines.map((line) => jsonDecode(line) as Map<String, dynamic>),
      everyElement(containsPair('event', 'test.event')),
    );
  });

  test('rotates to a new file when the local date changes', () async {
    await logger.info('test.before_midnight', 'before');
    now = DateTime(2026, 7, 14, 0, 0, 1);
    await logger.info('test.after_midnight', 'after');

    expect(
      File('${tempHome.path}/.mstages/logs/app-2026-07-13.log').existsSync(),
      isTrue,
    );
    expect(
      File('${tempHome.path}/.mstages/logs/app-2026-07-14.log').existsSync(),
      isTrue,
    );
  });

  test('retains seven days and leaves unrelated files untouched', () async {
    final logs = Directory('${tempHome.path}/.mstages/logs');
    await logs.create(recursive: true);
    final expired = File('${logs.path}/app-2026-07-06.log');
    final oldestRetained = File('${logs.path}/app-2026-07-07.log');
    final unrelated = File('${logs.path}/notes.txt');
    await expired.writeAsString('old');
    await oldestRetained.writeAsString('keep');
    await unrelated.writeAsString('keep');

    await logger.info('test.cleanup', 'cleanup');

    expect(expired.existsSync(), isFalse);
    expect(oldestRetained.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });
}
