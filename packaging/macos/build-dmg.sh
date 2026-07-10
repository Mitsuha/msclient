#!/usr/bin/env bash
# 把 macOS 的 .app 打成 .dmg。
#
# 用法: build-dmg.sh <version> <app_path> <out_dir>
#   app_path 通常是 build/macos/Build/Products/Release/desktop.app
# 依赖: create-dmg（brew install create-dmg），失败时回退到 hdiutil
set -euo pipefail

VERSION="${1:?version required}"
APP_PATH="${2:?app path required}"
OUT_DIR="${3:?out dir required}"

VOLNAME="Mirrorstages"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/MirrorStages-Desktop-${VERSION}-macos.dmg"
rm -f "$OUT_FILE"

if command -v create-dmg >/dev/null 2>&1; then
  # create-dmg 在“无可签名身份”时会返回非 0，但 dmg 已生成，故容错处理
  create-dmg \
    --volname "$VOLNAME" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "$(basename "$APP_PATH")" 165 200 \
    --app-drop-link 495 200 \
    --no-internet-enable \
    "$OUT_FILE" "$APP_PATH" || true
fi

if [ ! -f "$OUT_FILE" ]; then
  echo "create-dmg 未生成产物，回退到 hdiutil"
  STAGE="$(mktemp -d)"
  cp -R "$APP_PATH" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -ov -format UDZO "$OUT_FILE"
  rm -rf "$STAGE"
fi

echo "built: $OUT_FILE"
