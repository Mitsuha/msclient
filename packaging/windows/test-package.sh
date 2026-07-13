#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WXS="$SCRIPT_DIR/Package.wxs"
BUILDER="$SCRIPT_DIR/build-msi.ps1"

test -f "$WXS"
test -f "$BUILDER"
test ! -e "$SCRIPT_DIR/installer.iss"

grep -Fq 'Version="$(MsiVersion)"' "$WXS"
grep -Fq 'Files Include="$(SourceDir)\**"' "$WXS"
grep -Fq 'Directory="INSTALLFOLDER"' "$WXS"
grep -Fq 'ProgramFiles64Folder' "$WXS"
grep -Fq 'B3D9E2A1-7C4F-4E6A-9F2D-1A8C5E0B6D34' "$WXS"

grep -Fq 'desktop.exe' "$BUILDER"
grep -Fq "'^\\d+\\.\\d+\\.\\d+$'" "$BUILDER"
grep -Fq 'wix build' "$BUILDER"
grep -Fq 'MirrorStages-Desktop-$Version-windows-x64.msi' "$BUILDER"

printf 'Windows packaging static tests passed\n'
