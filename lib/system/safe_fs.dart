import 'dart:io';

/// [FileSystemEntity.exists]-style probe that treats an unreadable path as
/// absent instead of throwing.
///
/// `Directory.exists()` / `File.exists()` normally complete with `false` when
/// the target is missing, but on Windows they can *throw* a
/// [FileSystemException] when the path can't be traversed at all — e.g. a home
/// directory redirected through a reparse point Windows deems an "untrusted
/// mount point" (`ERROR_UNTRUSTED_MOUNT_POINT`, errno 448), as happens with
/// some OneDrive / corporate profile redirection setups.
///
/// Read-only status probes (is a tool installed? is there a backup to restore?)
/// must not crash the whole snapshot read over that: a path we cannot even
/// traverse has, for our purposes, nothing in it. Use this for those probes;
/// keep the raw `exists()` on write paths where the caller surfaces the error.
Future<bool> safeExists(FileSystemEntity entity) async {
  try {
    return await entity.exists();
  } on FileSystemException {
    return false;
  }
}
