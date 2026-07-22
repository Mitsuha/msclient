import 'dart:io';
import 'package:desktop/system/home_directory.dart';
import 'package:flutter/services.dart';

/// Copies the bundled CA to the application data directory. No system trust
/// store is modified.
class RootCertificateManager {
  RootCertificateManager({required this._home, required this.assetPath});
  final HomeDirectory _home;
  final String assetPath;

  Future<String> certificatePath() async =>
      '${await _home.resolve()}/.mstages/ms.cer';

  Future<void> install() async {
    try {
      final file = File(await certificatePath());
      await file.parent.create(recursive: true);
      final bytes = await rootBundle.load(assetPath);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } catch (_) {
      throw const RootCertificateInstallException('无法创建 Mirrorstages 相关的配置文件');
    }
  }

  Future<bool> isTrusted() async => File(await certificatePath()).exists();
}

class RootCertificateInstallException implements Exception {
  const RootCertificateInstallException(this.details, {this.guidance = ''});
  final String details;
  final String guidance;
  @override
  String toString() => details;
}
