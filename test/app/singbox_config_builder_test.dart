import 'package:desktop/app/singbox/singbox_config_builder.dart';
import 'package:desktop/data/models/client_proxy_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = SingboxConfigBuilder();

  ClientProxyOption option(String name, String url) =>
      ClientProxyOption(name: name, url: url);

  List<Map<String, dynamic>> proxyOutbounds(SingboxConfig config) =>
      (config.json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .where((o) => o['type'] == 'http')
          .toList();

  Map<String, dynamic> selectorOf(SingboxConfig config) =>
      (config.json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((o) => o['type'] == 'selector');

  test('one http outbound per node with tag from name', () {
    final config = builder.build([
      option('msc-1', 'https://msc-los.mirrorstages.com:5211'),
      option('msc-2', 'https://msc-sig.mirrorstages.com:5211'),
    ]);

    final outbounds = proxyOutbounds(config);
    expect(outbounds.map((o) => o['tag']), ['msc-1', 'msc-2']);
    expect(outbounds.first['server'], 'msc-los.mirrorstages.com');
    expect(outbounds.first['server_port'], 5211);
  });

  test('tls enabled follows the url scheme', () {
    final config = builder.build([
      option('secure', 'https://a.example.com:5211'),
      option('plain', 'http://b.example.com:8080'),
    ]);

    final outbounds = proxyOutbounds(config);
    expect((outbounds[0]['tls'] as Map)['enabled'], isTrue);
    expect((outbounds[1]['tls'] as Map)['enabled'], isFalse);
  });

  test('port defaults to 443/80 when the url omits it', () {
    final config = builder.build([
      option('secure', 'https://a.example.com'),
      option('plain', 'http://b.example.com'),
    ]);

    final outbounds = proxyOutbounds(config);
    expect(outbounds[0]['server_port'], 443);
    expect(outbounds[1]['server_port'], 80);
  });

  test('empty node names derive a tag from the host', () {
    final config = builder.build([
      option('', 'https://msc-los.mirrorstages.com:5211'),
    ]);

    expect(proxyOutbounds(config).single['tag'], 'msc-los');
  });

  test('duplicate names are suffixed to stay unique', () {
    final config = builder.build([
      option('node', 'https://a.example.com:5211'),
      option('node', 'https://b.example.com:5211'),
      option('node', 'https://c.example.com:5211'),
    ]);

    expect(proxyOutbounds(config).map((o) => o['tag']), [
      'node',
      'node-2',
      'node-3',
    ]);
  });

  test('selector.default is the selected node', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
      option('msc-2', 'https://b.example.com:5211'),
    ], selectedUrl: 'https://b.example.com:5211');

    expect(config.defaultTag, 'msc-2');
    expect(selectorOf(config)['default'], 'msc-2');
    expect(selectorOf(config)['outbounds'], ['msc-1', 'msc-2']);
  });

  test('selector.default falls back to the first node', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
      option('msc-2', 'https://b.example.com:5211'),
    ], selectedUrl: 'https://unknown.example.com:5211');

    expect(config.defaultTag, 'msc-1');
  });

  test('route forwards only the whitelist through the selector', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ]);

    final route = config.json['route'] as Map<String, dynamic>;
    final rule = (route['rules'] as List).single as Map<String, dynamic>;
    expect(rule['domain_suffix'], SingboxConfigBuilder.proxyDomains);
    expect(rule['outbound'], SingboxConfigBuilder.selectorTag);
    expect(rule['inbound'], [SingboxConfigBuilder.httpInboundTag]);
    expect(route['final'], SingboxConfigBuilder.directTag);
  });

  test('inbound and clash api reflect the configured host/ports', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ]);

    final inbound = (config.json['inbounds'] as List).single as Map;
    expect(inbound['listen'], '127.0.0.1');
    expect(inbound['listen_port'], 18610);

    final clash = ((config.json['experimental'] as Map)['clash_api']) as Map;
    expect(clash['external_controller'], '127.0.0.1:18611');
    expect(clash['secret'], 'default-secret');

    // A direct outbound is always present as the final fallback.
    final types = (config.json['outbounds'] as List)
        .cast<Map<String, dynamic>>()
        .map((o) => o['type']);
    expect(types, contains('direct'));
  });

  test('signature changes with the node set but not the selection', () {
    final a = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
      option('msc-2', 'https://b.example.com:5211'),
    ], selectedUrl: 'https://a.example.com:5211');
    final sameSetDifferentSelection = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
      option('msc-2', 'https://b.example.com:5211'),
    ], selectedUrl: 'https://b.example.com:5211');
    final differentSet = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ]);

    expect(a.outboundSignature, sameSetDifferentSelection.outboundSignature);
    expect(a.outboundSignature, isNot(differentSet.outboundSignature));
  });

  Map<String, dynamic>? networkProxyOf(SingboxConfig config) =>
      (config.json['outbounds'] as List)
          .cast<Map<String, dynamic>>()
          .where((o) => o['tag'] == SingboxConfigBuilder.networkProxyTag)
          .cast<Map<String, dynamic>?>()
          .firstWhere((_) => true, orElse: () => null);

  test('no network proxy keeps the final fallback as direct', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ]);

    expect(
      (config.json['route'] as Map)['final'],
      SingboxConfigBuilder.directTag,
    );
    expect(networkProxyOf(config), isNull);
  });

  test('a network proxy routes the final fallback through it', () {
    final config = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ], networkProxyUrl: 'http://127.0.0.1:7890');

    final network = networkProxyOf(config)!;
    expect(network['type'], 'http');
    expect(network['server'], '127.0.0.1');
    expect(network['server_port'], 7890);
    expect((network['tls'] as Map)['enabled'], isFalse);
    expect(
      (config.json['route'] as Map)['final'],
      SingboxConfigBuilder.networkProxyTag,
    );

    // The whitelist rule still points at the selector (only direct traffic
    // moves to the upstream proxy).
    final rule = ((config.json['route'] as Map)['rules'] as List).single as Map;
    expect(rule['outbound'], SingboxConfigBuilder.selectorTag);
  });

  test('a blank or unparseable network proxy falls back to direct', () {
    for (final value in ['', '   ', 'not a url', 'ftp://x']) {
      final config = builder.build([
        option('msc-1', 'https://a.example.com:5211'),
      ], networkProxyUrl: value);
      expect(
        (config.json['route'] as Map)['final'],
        SingboxConfigBuilder.directTag,
        reason: 'value "$value" should not enable the upstream proxy',
      );
      expect(networkProxyOf(config), isNull);
    }
  });

  test('the network proxy is part of the signature', () {
    final none = builder.build([option('msc-1', 'https://a.example.com:5211')]);
    final withProxy = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ], networkProxyUrl: 'http://127.0.0.1:7890');
    final differentProxy = builder.build([
      option('msc-1', 'https://a.example.com:5211'),
    ], networkProxyUrl: 'http://127.0.0.1:1080');

    expect(none.outboundSignature, isNot(withProxy.outboundSignature));
    expect(
      withProxy.outboundSignature,
      isNot(differentProxy.outboundSignature),
    );
  });

  test('isValidNetworkProxyUrl accepts http(s) urls with a host only', () {
    expect(
      SingboxConfigBuilder.isValidNetworkProxyUrl('http://127.0.0.1:7890'),
      isTrue,
    );
    expect(
      SingboxConfigBuilder.isValidNetworkProxyUrl('https://proxy.example.com'),
      isTrue,
    );
    expect(
      SingboxConfigBuilder.isValidNetworkProxyUrl('  http://127.0.0.1:7890  '),
      isTrue,
    );

    expect(SingboxConfigBuilder.isValidNetworkProxyUrl(''), isFalse);
    expect(SingboxConfigBuilder.isValidNetworkProxyUrl('   '), isFalse);
    expect(
      SingboxConfigBuilder.isValidNetworkProxyUrl('127.0.0.1:7890'),
      isFalse,
    );
    expect(SingboxConfigBuilder.isValidNetworkProxyUrl('ftp://x.com'), isFalse);
    expect(SingboxConfigBuilder.isValidNetworkProxyUrl('http://'), isFalse);
    expect(SingboxConfigBuilder.isValidNetworkProxyUrl('not a url'), isFalse);
  });
}
