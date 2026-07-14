import 'dart:io';

import 'package:desktop/system/safe_fs.dart';

/// Manages the one-time backup and later restore of the user's original Codex
/// configuration files (`auth.json` / `config.toml`).
///
/// Initialization overwrites/removes these files so MirrorStages can take over
/// the Codex auth and proxy setup. Before doing so we move the user's *original*
/// files into `~/.codex/old_config/`, letting the user roll back later.
///
/// The backup for a given file is written at most once: repeated
/// initializations never clobber the pristine originals with
/// MirrorStages-generated files.
class CodexConfigBackup {
  CodexConfigBackup(this.codexDirectory);

  /// The `~/.codex` directory whose config files are managed.
  final Directory codexDirectory;

  /// Sub-directory that holds the backed-up originals.
  static const backupDirectoryName = 'old_config';

  /// Config files that init replaces and that restore brings back.
  static const managedFileNames = ['auth.json', 'config.toml'];

  Directory get backupDirectory =>
      Directory('${codexDirectory.path}/$backupDirectoryName');

  File _liveFile(String name) => File('${codexDirectory.path}/$name');

  File _backupFile(String name) => File('${backupDirectory.path}/$name');

  /// Moves the user's *original* config files into [backupDirectory], once.
  ///
  /// A file is preserved only if it currently exists and has not already been
  /// backed up. Files that already have a backup are left untouched here so the
  /// caller can overwrite/remove the (MirrorStages-owned) live copy without
  /// destroying the pristine original.
  Future<void> preserveOriginals() async {
    for (final name in managedFileNames) {
      await preserveOriginal(name);
    }
  }

  /// Moves a single original config file into [backupDirectory], once, so an
  /// individual init step can be applied without touching the other files.
  Future<void> preserveOriginal(String name) async {
    final live = _liveFile(name);
    final backup = _backupFile(name);
    if (await live.exists() && !await backup.exists()) {
      await backupDirectory.create(recursive: true);
      await live.rename(backup.path);
    }
  }

  /// Whether there is at least one original config file available to restore.
  Future<bool> hasRestorableBackup() async {
    if (!await safeExists(backupDirectory)) {
      return false;
    }
    for (final name in managedFileNames) {
      if (await safeExists(_backupFile(name))) {
        return true;
      }
    }
    return false;
  }

  /// Restores every backed-up original: deletes the current live file (if any)
  /// and moves the backup back into place. Removes [backupDirectory] once it no
  /// longer holds any managed backups.
  ///
  /// Returns the names of the files that were restored.
  Future<List<String>> restore() async {
    final restored = <String>[];
    for (final name in managedFileNames) {
      final backup = _backupFile(name);
      if (!await backup.exists()) {
        continue;
      }
      final live = _liveFile(name);
      if (await live.exists()) {
        await live.delete();
      }
      await backup.rename(live.path);
      restored.add(name);
    }

    await _removeBackupDirectoryIfEmpty();
    return restored;
  }

  Future<void> _removeBackupDirectoryIfEmpty() async {
    if (!await backupDirectory.exists()) {
      return;
    }
    if (await backupDirectory.list().isEmpty) {
      await backupDirectory.delete();
    }
  }
}
