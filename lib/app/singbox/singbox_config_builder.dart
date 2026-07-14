import 'package:desktop/app/app_config.dart';
import 'package:desktop/data/models/client_proxy_models.dart';

/// The generated sing-box config plus the derived facts callers need: the tag
/// chosen as `selector.default` and a signature of the outbound set used to
/// decide between a live selector switch and a full restart.
class SingboxConfig {
  const SingboxConfig({
    required this.json,
    required this.defaultTag,
    required this.outboundSignature,
  });

  /// The full sing-box configuration to write to disk.
  final Map<String, dynamic> json;

  /// The tag written to `selector.default` (the active node).
  final String defaultTag;

  /// An ordered `tag|server|port|tls` list of the per-proxy outbounds (excludes
  /// the selector and direct). Equal signatures ⇒ the same set of nodes, so a
  /// selection change can be applied live over the Clash API; a different
  /// signature requires rewriting the file and restarting sing-box.
  final List<String> outboundSignature;
}

/// Turns the server's node list into a sing-box config: one `http` outbound per
/// node, a `selector` over them, a `direct` outbound, and a route that forwards
/// only the whitelisted domains through the selector (everything else direct).
///
/// Pure and I/O-free — turns the node list into the full sing-box config.
class SingboxConfigBuilder {
  const SingboxConfigBuilder({
    this.host = AppConfig.singboxHost,
    this.proxyPort = AppConfig.singboxProxyPort,
    this.apiPort = AppConfig.singboxApiPort,
    this.secret = AppConfig.singboxClashSecret,
  });

  final String host;
  final int proxyPort;
  final int apiPort;
  final String secret;

  static const httpInboundTag = 'default-http';
  static const selectorTag = 'default-selector';
  static const directTag = 'direct';

  /// Only these domains (and subdomains) are forwarded through the selector;
  /// everything else is dialed directly.
  static const proxyDomains = <String>[
    'chatgpt.com',
    'anthropic.com',
    'openai.com',
    'claude.com',
    'claude.ai',
    'api.anthropic.com',
    'platform.claude.com',
  ];

  SingboxConfig build(List<ClientProxyOption> proxies, {String? selectedUrl}) {
    final tags = <String>[];
    final outbounds = <Map<String, dynamic>>[];
    final signature = <String>[];
    final used = <String>{};
    String? selectedTag;

    for (final proxy in proxies) {
      final uri = Uri.parse(proxy.url);
      final overTls = uri.scheme == 'https';
      final port = uri.hasPort ? uri.port : (overTls ? 443 : 80);
      final tag = _uniqueTag(proxy, uri, used);
      tags.add(tag);
      if (selectedUrl != null &&
          proxy.url == selectedUrl &&
          selectedTag == null) {
        selectedTag = tag;
      }
      outbounds.add({
        'type': 'http',
        'tag': tag,
        'server': uri.host,
        'server_port': port,
        'tls': {'enabled': overTls},
      });
      signature.add('$tag|${uri.host}|$port|$overTls');
    }

    // Fall back to the first node when the selection is absent from the list.
    final defaultTag = selectedTag ?? tags.first;

    outbounds.add({
      'type': 'selector',
      'tag': selectorTag,
      'outbounds': List<String>.from(tags),
      'default': defaultTag,
    });
    outbounds.add({'type': 'direct', 'tag': directTag});

    final json = <String, dynamic>{
      'log': {'level': 'info'},
      'experimental': {
        'clash_api': {
          'external_controller': '$host:$apiPort',
          'secret': secret,
        },
      },
      'inbounds': [
        {
          'type': 'http',
          'tag': httpInboundTag,
          'listen': host,
          'listen_port': proxyPort,
        },
      ],
      'outbounds': outbounds,
      'route': {
        'rules': [
          {
            'inbound': [httpInboundTag],
            'domain_suffix': List<String>.from(proxyDomains),
            'outbound': selectorTag,
          },
        ],
        'final': directTag,
      },
    };

    return SingboxConfig(
      json: json,
      defaultTag: defaultTag,
      outboundSignature: signature,
    );
  }

  /// A non-empty, unique outbound tag derived from the node name (or its host
  /// when unnamed), suffixed `-2`, `-3`, … on collision. sing-box requires
  /// outbound tags to be unique.
  String _uniqueTag(ClientProxyOption proxy, Uri uri, Set<String> used) {
    var base = proxy.name.trim();
    if (base.isEmpty) {
      base = uri.host.split('.').first;
    }
    if (base.isEmpty) {
      base = 'node';
    }
    var tag = base;
    var suffix = 2;
    while (!used.add(tag)) {
      tag = '$base-$suffix';
      suffix++;
    }
    return tag;
  }
}
