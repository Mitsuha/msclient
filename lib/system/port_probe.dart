import 'dart:io';

/// Whether a TCP port is currently accepting connections. Used at first launch
/// to detect a local HTTP proxy (e.g. Clash on 127.0.0.1:7890) before the app
/// decides whether to route direct traffic through it.
///
/// Best-effort: any failure (nothing listening, refused, timeout) is a plain
/// `false`. The [timeout] is short so it never noticeably delays startup.
Future<bool> isTcpPortOpen(
  String host,
  int port, {
  Duration timeout = const Duration(milliseconds: 300),
}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
