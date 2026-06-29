import 'dart:convert';
import 'dart:io';

import 'package:desktop/features/control_panel/control_panel_models.dart';

class ControlPanelService {
  const ControlPanelService();

  static const _proxyValue = 'http://127.0.0.1:7890';

  Future<ControlPanelSnapshot> loadSnapshot() async {
    try {
      final conflicts = await findConflictProcesses();
      final initialization = await readInitializationStatus();
      final state = conflicts.isNotEmpty
          ? RuntimeState.conflict
          : initialization.isInitialized
          ? RuntimeState.running
          : RuntimeState.uninitialized;

      return ControlPanelSnapshot(
        state: state,
        account: await loadAccountSummary(),
        initialization: initialization,
        conflicts: conflicts,
      );
    } catch (error) {
      return ControlPanelSnapshot(
        state: RuntimeState.error,
        account: await loadAccountSummary(),
        initialization: await _emptyInitializationStatus(),
        message: error.toString(),
      );
    }
  }

  Future<AccountSummary> loadAccountSummary() async {
    return const AccountSummary(
      account: 'mirrorstages@example.com',
      nickname: 'MirrorStages User',
      balance: r'$128.00',
      planName: 'Professional Monthly',
      planExpiresAt: '2026-07-30',
    );
  }

  Future<List<ConflictProcess>> findConflictProcesses() async {
    final result = await Process.run('ps', ['-ef']);
    if (result.exitCode != 0) {
      throw ProcessException('ps', const ['-ef'], result.stderr.toString());
    }

    final currentPid = pid;
    final conflicts = <ConflictProcess>[];
    for (final line in result.stdout.toString().split('\n')) {
      if (!line.contains('cc-switch')) {
        continue;
      }
      if (line.contains('grep cc-switch')) {
        continue;
      }

      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 8) {
        continue;
      }

      final processPid = int.tryParse(parts[1]);
      if (processPid == null || processPid == currentPid) {
        continue;
      }

      conflicts.add(
        ConflictProcess(pid: processPid, command: parts.skip(7).join(' ')),
      );
    }

    return conflicts;
  }

  Future<InitializationStatus> readInitializationStatus() async {
    final home = _homeDirectory();
    final authPath = '$home/.codex/auth.json';
    final envPath = '$home/.codex/.env';
    final authFile = File(authPath);
    final envFile = File(envPath);

    var hasAccessToken = false;
    var hasAccountSharingMemberId = false;
    if (await authFile.exists()) {
      final jsonText = await authFile.readAsString();
      final auth = jsonDecode(jsonText);
      final tokenValue = auth is Map<String, dynamic>
          ? auth['tokens'] is Map<String, dynamic>
                ? (auth['tokens'] as Map<String, dynamic>)['access_token']
                : null
          : null;
      final token = tokenValue is String ? tokenValue : null;
      hasAccessToken = token != null && token.isNotEmpty;
      final payload = hasAccessToken ? decodeJwtPayload(token) : null;
      hasAccountSharingMemberId =
          payload?.containsKey('account_sharing_member_id') ?? false;
    }

    final env = await _readEnv(envFile);
    return InitializationStatus(
      authPath: authPath,
      envPath: envPath,
      hasAuthFile: await authFile.exists(),
      hasAccessToken: hasAccessToken,
      hasAccountSharingMemberId: hasAccountSharingMemberId,
      hasHttpProxy: env.containsKey('http_proxy'),
      hasHttpsProxy: env.containsKey('https_proxy'),
    );
  }

  Future<void> initializeLocalProxyEnv() async {
    final home = _homeDirectory();
    final codexDirectory = Directory('$home/.codex');
    final envFile = File('${codexDirectory.path}/.env');
    await codexDirectory.create(recursive: true);

    final env = await _readEnv(envFile);
    env['http_proxy'] = env['http_proxy']?.isNotEmpty == true
        ? env['http_proxy']!
        : _proxyValue;
    env['https_proxy'] = env['https_proxy']?.isNotEmpty == true
        ? env['https_proxy']!
        : _proxyValue;

    final lines = env.entries.map((entry) => '${entry.key}=${entry.value}');
    await envFile.writeAsString('${lines.join('\n')}\n');
  }

  Future<void> terminateConflicts(List<ConflictProcess> conflicts) async {
    for (final conflict in conflicts) {
      Process.killPid(conflict.pid, ProcessSignal.sigterm);
    }
  }

  Future<InitializationStatus> _emptyInitializationStatus() async {
    final home = _homeDirectory();
    return InitializationStatus(
      authPath: '$home/.codex/auth.json',
      envPath: '$home/.codex/.env',
      hasAuthFile: false,
      hasAccessToken: false,
      hasAccountSharingMemberId: false,
      hasHttpProxy: false,
      hasHttpsProxy: false,
    );
  }

  Future<Map<String, String>> _readEnv(File file) async {
    if (!await file.exists()) {
      return {};
    }

    final values = <String, String>{};
    for (final rawLine in await file.readAsLines()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }

      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }

    return values;
  }

  String _homeDirectory() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw const FileSystemException('HOME is not available');
    }
    return home;
  }
}
