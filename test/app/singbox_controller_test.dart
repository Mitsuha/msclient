import 'dart:convert';
import 'dart:io';

import 'package:desktop/app/singbox/singbox_config_builder.dart';
import 'package:desktop/app/singbox/singbox_controller.dart';
import 'package:desktop/core/logging/app_logger.dart';
import 'package:desktop/data/api/singbox_clash_api.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:desktop/system/singbox_binary.dart';
import 'package:desktop/system/singbox_process.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recording_app_logger.dart';

class _TestHome extends HomeDirectory {
  _TestHome(this.path);

  final String path;

  @override
  Future<String> resolve() async => path;
}

class _FakeBinary extends SingboxBinary {
  _FakeBinary(HomeDirectory home, AppLogger logger)
    : super(home: home, logger: logger);

  @override
  Future<String> ensureInstalled() async => '/fake/sing-box';
}

/// Shared liveness flag standing in for the sing-box process + Clash API pair.
class _FakeSingbox {
  bool alive = false;
}

class _FakeProcess extends SingboxProcess {
  _FakeProcess(this._box);

  final _FakeSingbox _box;
  int startCalls = 0;
  bool running = false;
  String? lastConfigPath;

  @override
  bool get isRunning => running;

  @override
  Future<void> start({
    required String binaryPath,
    required String configPath,
    required String logPath,
  }) async {
    startCalls++;
    running = true;
    lastConfigPath = configPath;
    _box.alive = true;
  }

  @override
  Future<void> stop() async {
    running = false;
    _box.alive = false;
  }
}

class _FakeApi extends SingboxClashApiClient {
  _FakeApi(this._box)
    : super(baseUri: Uri.parse('http://127.0.0.1:1/'), secret: 'x');

  final _FakeSingbox _box;
  final selections = <String>[];

  @override
  Future<bool> ping() async => _box.alive;

  @override
  Future<void> selectOutbound({
    required String selector,
    required String outboundTag,
  }) async {
    selections.add(outboundTag);
  }

  @override
  void close() {}
}

void main() {
  late Directory tempHome;
  late _FakeSingbox box;
  late _FakeProcess process;
  late _FakeApi api;
  late SingboxController controller;

  ClientProxyOption option(String name, String url) =>
      ClientProxyOption(name: name, url: url);

  final nodesA = [
    option('msc-1', 'https://a.example.com:5211'),
    option('msc-2', 'https://b.example.com:5211'),
  ];

  setUp(() async {
    tempHome = await Directory.systemTemp.createTemp(
      'singbox_controller_test_',
    );
    box = _FakeSingbox();
    process = _FakeProcess(box);
    api = _FakeApi(box);
    final home = _TestHome(tempHome.path);
    controller = SingboxController(
      binary: _FakeBinary(home, RecordingAppLogger()),
      process: process,
      api: api,
      builder: const SingboxConfigBuilder(),
      home: home,
      logger: RecordingAppLogger(),
    );
  });

  tearDown(() async {
    await tempHome.delete(recursive: true);
  });

  Future<Map<String, dynamic>> readConfig() async {
    final file = File(process.lastConfigPath!);
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  String selectorDefault(Map<String, dynamic> config) =>
      (config['outbounds'] as List).cast<Map<String, dynamic>>().firstWhere(
            (o) => o['type'] == 'selector',
          )['default']
          as String;

  test(
    'first apply installs, writes config, starts, and becomes healthy',
    () async {
      await controller.apply(nodesA, selectedUrl: 'https://a.example.com:5211');

      expect(process.startCalls, 1);
      expect(controller.isReady, isTrue);
      expect(await controller.isHealthy(), isTrue);
      expect(api.selections, isEmpty);

      final config = await readConfig();
      expect(selectorDefault(config), 'msc-1');
      expect(File(process.lastConfigPath!).existsSync(), isTrue);
    },
  );

  test(
    'same node set with a new selection switches live without restart',
    () async {
      await controller.apply(nodesA, selectedUrl: 'https://a.example.com:5211');
      await controller.apply(nodesA, selectedUrl: 'https://b.example.com:5211');

      expect(process.startCalls, 1);
      expect(api.selections, ['msc-2']);
      // The config file is rewritten so the new default survives a restart.
      expect(selectorDefault(await readConfig()), 'msc-2');
    },
  );

  test('a changed node set rewrites the config and restarts', () async {
    await controller.apply(nodesA, selectedUrl: 'https://a.example.com:5211');
    await controller.apply([
      option('msc-1', 'https://a.example.com:5211'),
    ], selectedUrl: 'https://a.example.com:5211');

    expect(process.startCalls, 2);
    expect(api.selections, isEmpty);
  });

  test('an unchanged apply is a no-op', () async {
    await controller.apply(nodesA, selectedUrl: 'https://a.example.com:5211');
    await controller.apply(nodesA, selectedUrl: 'https://a.example.com:5211');

    expect(process.startCalls, 1);
    expect(api.selections, isEmpty);
  });

  test('concurrent applies serialize to a single launch', () async {
    final first = controller.apply(
      nodesA,
      selectedUrl: 'https://a.example.com:5211',
    );
    final second = controller.apply(
      nodesA,
      selectedUrl: 'https://a.example.com:5211',
    );
    await Future.wait([first, second]);

    expect(process.startCalls, 1);
  });

  test('an empty node list is ignored', () async {
    await controller.apply(const []);

    expect(process.startCalls, 0);
    expect(controller.isReady, isFalse);
  });
}
