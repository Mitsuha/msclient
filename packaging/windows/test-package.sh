#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WXS="$SCRIPT_DIR/Package.wxs"
UI_WXS="$SCRIPT_DIR/InstallerUI.wxs"
BUILDER="$SCRIPT_DIR/build-msi.ps1"
WORKFLOW="$SCRIPT_DIR/../../.github/workflows/shorebird-release.yml"

test -f "$WXS"
test -f "$UI_WXS"
test -f "$BUILDER"
test -f "$WORKFLOW"
test ! -e "$SCRIPT_DIR/installer.iss"

grep -Fq 'Version="$(MsiVersion)"' "$WXS"
grep -Fq '<MediaTemplate EmbedCab="yes" />' "$WXS"
grep -Fq '<MajorUpgrade' "$WXS"
grep -Fq 'Name="Mirrorstages"' "$WXS"
grep -Fq 'Id="StartMenuShortcut"' "$WXS"
grep -Fq 'Id="DesktopShortcut"' "$WXS"
grep -Fq 'Condition="CREATE_DESKTOP_SHORTCUT = 1"' "$WXS"
grep -Fq 'Id="CREATE_DESKTOP_SHORTCUT" Value="1"' "$WXS"
grep -Fq 'Id="WIXUI_EXITDIALOGOPTIONALCHECKBOX" Value="1"' "$WXS"
grep -Fq 'Id="LaunchApplication"' "$WXS"
grep -Fq 'Files Include="$(SourceDir)\**"' "$WXS"
grep -Fq 'Directory="INSTALLFOLDER"' "$WXS"
grep -Fq 'ProgramFiles64Folder' "$WXS"
grep -Fq 'B3D9E2A1-7C4F-4E6A-9F2D-1A8C5E0B6D34' "$WXS"

grep -Fq 'desktop.exe' "$BUILDER"
grep -Fq "'^\\d+\\.\\d+\\.\\d+$'" "$BUILDER"
grep -Fq 'wix build' "$BUILDER"
grep -Fq 'WixToolset.UI.wixext/5.0.2' "$BUILDER"
grep -Fq -- '-ext WixToolset.UI.wixext' "$BUILDER"
grep -Fq 'InstallerUI.wxs' "$BUILDER"
grep -Fq 'MirrorStages-Desktop-$Version-windows-x64.msi' "$BUILDER"

grep -Fq 'Id="OptionsDlg"' "$UI_WXS"
grep -Fq 'Property="CREATE_DESKTOP_SHORTCUT"' "$UI_WXS"
grep -Fq 'CheckBoxValue="1"' "$UI_WXS"
grep -Fq 'Value="LaunchApplication"' "$UI_WXS"
grep -Fq 'Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER"' "$UI_WXS"
grep -Fq 'Dialog="InstallDirDlg" Control="ChangeFolder"' "$UI_WXS"
grep -Fq 'Event="SpawnDialog" Value="BrowseDlg"' "$UI_WXS"
if grep -Fq 'Dialog="BrowseDlg" Control="OK"' "$UI_WXS"; then
  echo 'BrowseDlg OK events are already provided by WixUI_Common' >&2
  exit 1
fi

grep -Fq 'https://cnb.cool/mirrorstages/gost/-/git/raw/main/sing-box.exe' "$WORKFLOW"
grep -Fq 'build/windows/x64/runner/Release/sing-box.exe' "$WORKFLOW"

printf 'Windows packaging static tests passed\n'
