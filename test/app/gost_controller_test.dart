import 'package:desktop/app/gost/gost_controller.dart';
import 'package:desktop/data/api/gost_api.dart';
import 'package:desktop/system/gost_binary.dart';
import 'package:desktop/system/gost_process.dart';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeHome extends HomeDirectory {
  @override
  Future<String> resolve() async => '/fake-home';
}

class _FakeBinary extends GostBinary {
  _FakeBinary() : super(home: _FakeHome());

  @override
  Future<String> ensureInstalled() async => '/fake-home/.mstages/bin/gost';
}

/// Shared state standing in for the gost process + control API pair.
///
/// [dieOnNextPush] models the orphan-adoption failure: a gost inherited from a
/// crashed session answers `ping`, but the log write provoked by the first
/// config push kills it (its stdio pipes broke with the old parent).
class _FakeGost {
  bool alive = false;
  bool dieOnNextPush = false;

  /// The push errors (e.g. a 400 from the API) but gost stays up.
  bool failNextPush = false;
}

class _FakeProcess extends GostProcess {
  _FakeProcess(this._gost);

  final _FakeGost _gost;
  int startCalls = 0;
  bool running = false;

  @override
  bool get isRunning => running;

  @override
  Future<void> start({
    required String binaryPath,
    required String apiAddress,
    required String logPath,
  }) async {
    startCalls++;
    running = true;
    _gost.alive = true;
  }

  @override
  Future<void> stop() async {
    running = false;
    _gost.alive = false;
  }
}

class _FakeApi extends GostApiClient {
  _FakeApi(this._gost) : super(baseUri: Uri.parse('http://127.0.0.1:1/'));

  final _FakeGost _gost;
  final pushes = <String>[];

  @override
  Future<bool> ping() async => _gost.alive;

  Future<void> _push(String kind, String name) async {
    if (_gost.dieOnNextPush) {
      _gost.dieOnNextPush = false;
      _gost.alive = false;
    }
    if (!_gost.alive) {
      throw http.ClientException('Connection reset by peer');
    }
    if (_gost.failNextPush) {
      _gost.failNextPush = false;
      throw http.ClientException('gost API 400: bad request');
    }
    pushes.add('$kind/$name');
  }

  @override
  Future<void> upsertBypass(String name, Map<String, dynamic> body) =>
      _push('bypasses', name);

  @override
  Future<void> upsertChain(String name, Map<String, dynamic> body) =>
      _push('chains', name);

  @override
  Future<void> upsertService(String name, Map<String, dynamic> body) =>
      _push('services', name);

  @override
  void close() {}
}

void main() {
  const fullPush = [
    'bypasses/mstages-proxy',
    'chains/mstages',
    'services/mstages-local',
  ];

  late _FakeGost gost;
  late _FakeProcess process;
  late _FakeApi api;
  late GostController controller;

  setUp(() {
    gost = _FakeGost();
    process = _FakeProcess(gost);
    api = _FakeApi(gost);
    controller = GostController(
      binary: _FakeBinary(),
      process: process,
      api: api,
      home: _FakeHome(),
    );
  });

  test('spawns gost and pushes config when nothing is running', () async {
    await controller.start();
    await controller.applyProxyNode('https://node.example.com');

    expect(process.startCalls, 1);
    expect(api.pushes, fullPush);
  });

  test('adopted orphan dying at first push → respawn and reapply', () async {
    // An orphan from a crashed session: answers ping, dies on the first push.
    gost
      ..alive = true
      ..dieOnNextPush = true;

    await controller.start();
    expect(process.startCalls, 0, reason: 'ping succeeded, so it was adopted');

    await controller.applyProxyNode('https://node.example.com');

    expect(process.startCalls, 1, reason: 'took over after the orphan died');
    expect(api.pushes, fullPush);
  });

  test('own gost dying later → next apply respawns from scratch', () async {
    await controller.start();
    await controller.applyProxyNode('https://a.example.com');
    expect(api.pushes, fullPush);

    // gost dies on its own; GostProcess's exit watcher drops the handle.
    gost.alive = false;
    process.running = false;

    await controller.applyProxyNode('https://b.example.com');
    expect(process.startCalls, 2);
    expect(api.pushes, [...fullPush, ...fullPush]);
  });

  test('concurrent applies of the same node collapse to one push', () async {
    gost.alive = true;
    await controller.start();

    await Future.wait([
      controller.applyProxyNode('https://node.example.com'),
      controller.applyProxyNode('https://node.example.com'),
    ]);

    expect(api.pushes, fullPush);
  });

  test('a live gost failing a push is not respawned over', () async {
    gost.alive = true;
    await controller.start();
    await controller.applyProxyNode('https://a.example.com');

    // The API errors but gost itself is still up: no takeover.
    gost.failNextPush = true;

    await expectLater(
      controller.applyProxyNode('https://b.example.com'),
      throwsA(isA<http.ClientException>()),
    );
    expect(process.startCalls, 0);
  });
}
