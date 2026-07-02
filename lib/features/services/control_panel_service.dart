import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/core/session/session_store.dart';
import 'package:desktop/features/models/account_models.dart';
import 'package:desktop/features/api/auth_api.dart';
import 'package:desktop/features/api/codex_auth_api.dart';
import 'package:desktop/features/models/control_panel_models.dart';
import 'package:desktop/features/api/dashboard_api.dart';
import 'package:desktop/features/api/user_pack_api.dart';

class ControlPanelService {
  const ControlPanelService({
    required SessionStore sessionStore,
    required AuthApi authApi,
    required CodexAuthApi codexAuthApi,
    required DashboardApi dashboardApi,
    required UserPackApi userPackApi,
  }) : this._(sessionStore, authApi, codexAuthApi, dashboardApi, userPackApi);

  const ControlPanelService._(
    this._sessionStore,
    this._authApi,
    this._codexAuthApi,
    this._dashboardApi,
    this._userPackApi,
  );

  static const _proxyValue = 'https://api.mirrorstages.com:5211';
  static const _adminConsoleUrl = 'https://dashboard.mirrorstages.com';
  static const _rootCertificateAssetPath = 'assets/ca/mirrorstages-root-ca.cer';
  static const _processInspector = MethodChannel(
    'com.mirrorstages.desktop/process_inspector',
  );

  final SessionStore _sessionStore;
  final AuthApi _authApi;
  final CodexAuthApi _codexAuthApi;
  final DashboardApi _dashboardApi;
  final UserPackApi _userPackApi;

  static ControlPanelService local() {
    final client = ApiClient(
      baseUri: Uri.parse('https://platform.mirrorstages.com/api'),
    );
    return ControlPanelService(
      sessionStore: const SessionStore(),
      authApi: AuthApi(client),
      codexAuthApi: CodexAuthApi(client),
      dashboardApi: DashboardApi(client),
      userPackApi: UserPackApi(client),
    );
  }

  Future<bool> hasSession() async {
    return await _sessionStore.load() != null;
  }

  Future<void> login({
    required String account,
    required String password,
  }) async {
    final isEmail = account.contains('@');
    final result = await _authApi.login(
      email: isEmail ? account : null,
      phone: isEmail ? null : account,
      password: password,
    );
    await _sessionStore.save(
      SessionState(token: result.token, user: result.user),
    );
  }

  Future<void> logout() => _sessionStore.clear();

  Future<void> openAdminConsole() async {
    if (Platform.isMacOS) {
      await Process.run('open', [_adminConsoleUrl]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', _adminConsoleUrl]);
      return;
    }
    await Process.run('xdg-open', [_adminConsoleUrl]);
  }

  Future<void> installRootCertificate() async {
    if (Platform.isMacOS) {
      await _installMacOsRootCertificate();
      return;
    }

    if (Platform.isWindows) {
      await _installWindowsRootCertificate();
      return;
    }

    throw UnsupportedError(
      'Root certificate installation is not supported on this platform.',
    );
  }

  Future<void> _installMacOsRootCertificate() async {
    final certificateFile = await _copyRootCertificateToTemporaryFile();
    final result = await Process.run('/usr/bin/security', [
      'add-trusted-cert',
      '-r',
      'trustRoot',
      '-p',
      'ssl',
      '-p',
      'basic',
      '-k',
      await _loginKeychainPath(),
      certificateFile.path,
    ]);
    if (result.exitCode != 0) {
      throw RootCertificateInstallException(
        _processFailureDetails(result),
        guidance: '请确认登录钥匙串可写后重试。',
      );
    }
  }

  Future<void> _installWindowsRootCertificate() async {
    final certificateFile = await _copyRootCertificateToTemporaryFile();
    final result = await _runPowerShell('''
\$ErrorActionPreference = 'Stop'
Import-Certificate -FilePath '${_escapePowerShellSingleQuoted(certificateFile.path)}' -CertStoreLocation Cert:\\CurrentUser\\Root | Out-Null
''');
    if (result.exitCode != 0) {
      throw RootCertificateInstallException(
        _processFailureDetails(result),
        guidance: '请确认当前 Windows 用户证书存储可写后重试。',
      );
    }
  }

  String _processFailureDetails(ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    return result.stdout.toString().trim();
  }

  Future<ControlPanelSnapshot> loadSnapshot() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    try {
      final overview = await _dashboardApi.overview(token: session.token);
      final packList = await _userPackApi.listActive(token: session.token);
      final dashboard = DashboardData(
        user: session.user,
        overview: overview,
        packs: packList.packs,
      );

      var localCheckError = '';
      var conflicts = const <ConflictProcess>[];
      try {
        conflicts = await findConflictProcesses();
      } catch (error) {
        localCheckError = error.toString();
      }

      final initialization = await _readInitializationStatusSafely(
        currentError: localCheckError,
        onError: (error) => localCheckError = error,
      );
      final localConfiguration = await readLocalConfigurationStatus();
      final state = conflicts.isNotEmpty
          ? RuntimeState.conflict
          : !localConfiguration.rootCertificate.isInstalled
          ? RuntimeState.rootCertificateMissing
          : localCheckError.isNotEmpty
          ? RuntimeState.error
          : initialization.isInitialized
          ? RuntimeState.running
          : RuntimeState.uninitialized;

      return ControlPanelSnapshot(
        state: state,
        account: dashboard.accountSummary,
        initialization: initialization,
        localConfiguration: localConfiguration,
        dashboard: dashboard,
        conflicts: conflicts,
        message: localCheckError.isEmpty ? null : localCheckError,
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _sessionStore.clear();
        throw const UnauthenticatedException();
      }
      return ControlPanelSnapshot(
        state: RuntimeState.error,
        account: _accountFor(session.user),
        initialization: await _emptyInitializationStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    } catch (error) {
      return ControlPanelSnapshot(
        state: RuntimeState.error,
        account: _accountFor(session.user),
        initialization: await _emptyInitializationStatus(),
        localConfiguration: await _emptyLocalConfigurationStatus(),
        message: error.toString(),
      );
    }
  }

  Future<InitializationStatus> _readInitializationStatusSafely({
    required String currentError,
    required void Function(String error) onError,
  }) async {
    try {
      return await readInitializationStatus();
    } catch (error) {
      if (currentError.isEmpty) {
        onError(error.toString());
      }
      return _emptyInitializationStatus();
    }
  }

  AccountSummary _accountFor(UserProfile user) {
    return AccountSummary(
      account: user.displayAccount,
      nickname: user.nickname.isEmpty ? '-' : user.nickname,
      balance: '-',
      planName: '-',
      planExpiresAt: '-',
    );
  }

  Future<List<ConflictProcess>> findConflictProcesses() async {
    if (Platform.isMacOS) {
      return _findMacOsConflictProcesses();
    }

    if (Platform.isWindows) {
      return _findWindowsConflictProcesses();
    }

    return _findShellConflictProcesses();
  }

  Future<List<ConflictProcess>> _findMacOsConflictProcesses() async {
    final results = await _processInspector.invokeListMethod<Object?>(
      'findConflictProcesses',
    );
    if (results == null) {
      return const [];
    }

    return results
        .whereType<Map<Object?, Object?>>()
        .map((item) {
          final pidValue = item['pid'];
          return ConflictProcess(
            pid: pidValue is int ? pidValue : int.tryParse('$pidValue') ?? 0,
            command: item['command']?.toString() ?? 'cc-switch',
          );
        })
        .where((item) => item.pid > 0)
        .toList();
  }

  Future<List<ConflictProcess>> _findShellConflictProcesses() async {
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

  Future<List<ConflictProcess>> _findWindowsConflictProcesses() async {
    final result = await Process.run('tasklist.exe', ['/fo', 'csv', '/nh']);
    if (result.exitCode != 0) {
      throw ProcessException(
        'tasklist.exe',
        const ['/fo', 'csv', '/nh'],
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final conflicts = <ConflictProcess>[];
    for (final row in const LineSplitter().convert(result.stdout.toString())) {
      final columns = _parseCsvRow(row);
      if (columns.length < 2) {
        continue;
      }

      final imageName = columns[0];
      if (!imageName.toLowerCase().contains('cc-switch')) {
        continue;
      }

      final processPid = int.tryParse(columns[1]);
      if (processPid == null || processPid == pid) {
        continue;
      }

      conflicts.add(ConflictProcess(pid: processPid, command: imageName));
    }

    return conflicts;
  }

  Future<InitializationStatus> readInitializationStatus() async {
    final home = await _homeDirectory();
    final authPath = '$home/.codex/auth.json';
    final envPath = '$home/.codex/.env';
    final configPath = '$home/.codex/config.toml';
    final authFile = File(authPath);
    final envFile = File(envPath);
    final configFile = File(configPath);

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
    final hasCodexProviderOverride = await _hasCodexProviderOverride(
      configFile,
    );
    return InitializationStatus(
      authPath: authPath,
      envPath: envPath,
      configPath: configPath,
      hasAuthFile: await authFile.exists(),
      hasAccessToken: hasAccessToken,
      hasAccountSharingMemberId: hasAccountSharingMemberId,
      hasHttpProxy: env['http_proxy']?.isNotEmpty == true,
      hasHttpsProxy: env['https_proxy']?.isNotEmpty == true,
      hasCodexProviderOverride: hasCodexProviderOverride,
    );
  }

  Future<LocalConfigurationStatus> readLocalConfigurationStatus() async {
    final home = await _homeDirectory();
    final codexDirectory = Directory('$home/.codex');
    final claudeDirectory = Directory('$home/.claude');
    return LocalConfigurationStatus(
      codexDirectoryPath: codexDirectory.path,
      claudeDirectoryPath: claudeDirectory.path,
      isCodexInstalled: await codexDirectory.exists(),
      isClaudeInstalled: await claudeDirectory.exists(),
      rootCertificate: await readRootCertificateStatus(),
    );
  }

  Future<RootCertificateStatus> readRootCertificateStatus() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return const RootCertificateStatus(
        assetPath: _rootCertificateAssetPath,
        isInstalled: false,
      );
    }

    final certificateFile = await _copyRootCertificateToTemporaryFile();
    final installed = Platform.isWindows
        ? await _isWindowsRootCertificateTrusted(certificateFile.path)
        : await _isMacOsRootCertificateTrusted(certificateFile.path);
    return RootCertificateStatus(
      assetPath: _rootCertificateAssetPath,
      isInstalled: installed,
    );
  }

  Future<void> initializeLocalProxyEnv() async {
    final session = await _sessionStore.load();
    if (session == null) {
      throw const UnauthenticatedException();
    }

    final home = await _homeDirectory();
    final codexDirectory = Directory('$home/.codex');
    final authFile = File('${codexDirectory.path}/auth.json');
    final envFile = File('${codexDirectory.path}/.env');
    final configFile = File('${codexDirectory.path}/config.toml');
    await codexDirectory.create(recursive: true);

    final codexAuth = await _codexAuthApi.createAuth(token: session.token);
    await authFile.writeAsString(_prettyJson(codexAuth));

    final env = await _readEnv(envFile);
    env['http_proxy'] = _proxyValue;
    env['https_proxy'] = _proxyValue;

    final lines = env.entries.map((entry) => '${entry.key}=${entry.value}');
    await envFile.writeAsString('${lines.join('\n')}\n');

    if (await configFile.exists()) {
      await configFile.delete();
    }
  }

  String _prettyJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(json)}\n';
  }

  Future<InitializationStatus> _emptyInitializationStatus() async {
    final home = await _homeDirectory();
    return InitializationStatus(
      authPath: '$home/.codex/auth.json',
      envPath: '$home/.codex/.env',
      configPath: '$home/.codex/config.toml',
      hasAuthFile: false,
      hasAccessToken: false,
      hasAccountSharingMemberId: false,
      hasHttpProxy: false,
      hasHttpsProxy: false,
      hasCodexProviderOverride: false,
    );
  }

  Future<bool> _hasCodexProviderOverride(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final text = await file.readAsString();
    return text.contains('base_url') && text.contains('model_provider');
  }

  Future<LocalConfigurationStatus> _emptyLocalConfigurationStatus() async {
    final home = await _homeDirectory();
    return LocalConfigurationStatus(
      codexDirectoryPath: '$home/.codex',
      claudeDirectoryPath: '$home/.claude',
      isCodexInstalled: false,
      isClaudeInstalled: false,
      rootCertificate: const RootCertificateStatus(
        assetPath: _rootCertificateAssetPath,
        isInstalled: false,
      ),
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

  Future<String> _homeDirectory() async {
    if (Platform.isMacOS) {
      final nativeHome = await _processInspector.invokeMethod<String>(
        'userHomeDirectory',
      );
      if (nativeHome != null && nativeHome.isNotEmpty) {
        return nativeHome;
      }
    }

    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw FileSystemException(
        Platform.isWindows
            ? 'USERPROFILE is not available'
            : 'HOME is not available',
      );
    }
    return home;
  }

  Future<File> _copyRootCertificateToTemporaryFile() async {
    final bytes = await rootBundle.load(_rootCertificateAssetPath);
    final directory = Directory('${Directory.systemTemp.path}/mirrorstages');
    await directory.create(recursive: true);
    final file = File('${directory.path}/mirrorstages-root-ca.cer');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<String> _certificateFingerprint(String certificatePath) async {
    final result = await Process.run('/usr/bin/openssl', [
      'x509',
      '-in',
      certificatePath,
      '-noout',
      '-fingerprint',
      '-sha256',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        '/usr/bin/openssl',
        const ['x509', '-fingerprint'],
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final output = result.stdout.toString().trim();
    final separator = output.indexOf('=');
    if (separator < 0) {
      throw const FormatException('Certificate fingerprint is missing.');
    }
    return _normalizeFingerprint(output.substring(separator + 1));
  }

  Future<bool> _isMacOsRootCertificateTrusted(String certificatePath) async {
    final fingerprint = await _certificateFingerprint(certificatePath);
    return await _trustedKeychainsContainFingerprint(fingerprint) &&
        await _isMacOsCertificateTrusted(certificatePath);
  }

  Future<bool> _isWindowsRootCertificateTrusted(String certificatePath) async {
    final result = await _runPowerShell('''
\$ErrorActionPreference = 'Stop'
\$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('${_escapePowerShellSingleQuoted(certificatePath)}')
\$sha256 = [System.Security.Cryptography.SHA256]::Create()
\$target = ([BitConverter]::ToString(\$sha256.ComputeHash(\$cert.RawData))).Replace('-', '')
\$stores = @('Cert:\\CurrentUser\\Root', 'Cert:\\LocalMachine\\Root')
foreach (\$store in \$stores) {
  foreach (\$item in Get-ChildItem -Path \$store -ErrorAction SilentlyContinue) {
    \$hash = ([BitConverter]::ToString(\$sha256.ComputeHash(\$item.RawData))).Replace('-', '')
    if (\$hash -eq \$target) {
      exit 0
    }
  }
}
exit 1
''');
    return result.exitCode == 0;
  }

  Future<bool> _trustedKeychainsContainFingerprint(String fingerprint) async {
    for (final keychain in [
      await _loginKeychainPath(),
      '/Library/Keychains/System.keychain',
    ]) {
      final result = await Process.run('/usr/bin/security', [
        'find-certificate',
        '-a',
        '-Z',
        keychain,
      ]);
      if (result.exitCode != 0) {
        continue;
      }

      final haystack = _normalizeFingerprint(result.stdout.toString());
      if (haystack.contains(fingerprint)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _isMacOsCertificateTrusted(String certificatePath) async {
    final result = await Process.run('/usr/bin/security', [
      'verify-cert',
      '-c',
      certificatePath,
      '-p',
      'ssl',
    ]);
    return result.exitCode == 0;
  }

  Future<ProcessResult> _runPowerShell(String script) {
    return Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
  }

  String _normalizeFingerprint(String value) {
    return value.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  }

  String _escapePowerShellSingleQuoted(String value) {
    return value.replaceAll("'", "''");
  }

  List<String> _parseCsvRow(String row) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < row.length; index += 1) {
      final char = row[index];
      if (char == '"') {
        if (inQuotes && index + 1 < row.length && row[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }

    values.add(buffer.toString());
    return values;
  }

  Future<String> _loginKeychainPath() async {
    final home = await _homeDirectory();
    final keychain = File('$home/Library/Keychains/login.keychain-db');
    if (await keychain.exists()) {
      return keychain.path;
    }
    return '$home/Library/Keychains/login.keychain';
  }
}

class UnauthenticatedException implements Exception {
  const UnauthenticatedException();
}

class RootCertificateInstallException implements Exception {
  const RootCertificateInstallException(this.details, {required this.guidance});

  final String details;
  final String guidance;

  @override
  String toString() {
    if (details.isEmpty) {
      return '无法安装根证书，$guidance';
    }
    return '无法安装根证书，$guidance $details';
  }
}
