import 'dart:io';

import 'package:desktop/system/home_directory.dart';
import 'package:flutter/services.dart';

/// Installs the MirrorStages root certificate into the OS trust store and
/// checks whether it is currently trusted. Only macOS and Windows are
/// supported; [isTrusted] reports false elsewhere.
class RootCertificateManager {
  RootCertificateManager({required this._home, required this.assetPath});

  final HomeDirectory _home;

  /// Bundle path of the certificate, also displayed in the UI.
  final String assetPath;

  Future<void> install() async {
    if (Platform.isMacOS) {
      await _installMacOs();
      return;
    }

    if (Platform.isWindows) {
      await _installWindows();
      return;
    }

    throw UnsupportedError(
      'Root certificate installation is not supported on this platform.',
    );
  }

  Future<bool> isTrusted() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return false;
    }

    final certificateFile = await _copyToTemporaryFile();
    return Platform.isWindows
        ? _isWindowsTrusted(certificateFile.path)
        : _isMacOsTrusted(certificateFile.path);
  }

  Future<void> _installMacOs() async {
    final certificateFile = await _copyToTemporaryFile();
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

  Future<void> _installWindows() async {
    final certificateFile = await _copyToTemporaryFile();
    final result = await Process.run('certutil.exe', [
      '-user',
      '-f',
      '-addstore',
      'Root',
      certificateFile.path,
    ]);
    if (result.exitCode != 0) {
      throw RootCertificateInstallException(
        _processFailureDetails(result),
        guidance: '请确认当前 Windows 用户证书存储可写后重试。',
      );
    }

    if (!await _isWindowsTrusted(certificateFile.path)) {
      throw const RootCertificateInstallException(
        '系统未能在当前用户的受信任根证书存储中找到该证书。',
        guidance: '请检查 Windows 证书策略后重试。',
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

  Future<File> _copyToTemporaryFile() async {
    final bytes = await rootBundle.load(assetPath);
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

  Future<bool> _isMacOsTrusted(String certificatePath) async {
    final fingerprint = await _certificateFingerprint(certificatePath);
    return await _trustedKeychainsContainFingerprint(fingerprint) &&
        await _isMacOsCertificateVerified(certificatePath);
  }

  Future<bool> _isWindowsTrusted(String certificatePath) async {
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

  Future<bool> _isMacOsCertificateVerified(String certificatePath) async {
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

  Future<String> _loginKeychainPath() async {
    final home = await _home.resolve();
    final keychain = File('$home/Library/Keychains/login.keychain-db');
    if (await keychain.exists()) {
      return keychain.path;
    }
    return '$home/Library/Keychains/login.keychain';
  }
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
