#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"
APP_PATH="${2:?app path required}"
OUT_DIR="${3:?out dir required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKGROUND="$SCRIPT_DIR/background.png"
README="$SCRIPT_DIR/README.txt"
CREATE_DMG="${CREATE_DMG:-create-dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: macOS app not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND" ]]; then
  echo "error: DMG background not found: $BACKGROUND" >&2
  exit 1
fi

if [[ ! -f "$README" ]]; then
  echo "error: DMG README not found: $README" >&2
  exit 1
fi

if ! command -v "$CREATE_DMG" >/dev/null 2>&1; then
  echo "error: create-dmg is not installed or not executable: $CREATE_DMG" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
OUT_FILE="$OUT_DIR/MirrorStages-Desktop-${VERSION}-macos.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_PATH" "$STAGING/Mirrorstages.app"
cp "$README" "$STAGING/README.txt"
rm -f "$OUT_FILE"

set +e
"$CREATE_DMG" \
  --volname "MirrorStages" \
  --background "$BACKGROUND" \
  --window-size 700 520 \
  --icon-size 80 \
  --icon "Mirrorstages.app" 225 315 \
  --hide-extension "Mirrorstages.app" \
  --icon "README.txt" 360 110 \
  --app-drop-link 445 315 \
  "$OUT_FILE" \
  "$STAGING"
CREATE_DMG_STATUS=$?
set -e

if [[ ! -f "$OUT_FILE" ]]; then
  echo "error: create-dmg failed with status $CREATE_DMG_STATUS" >&2
  if (( CREATE_DMG_STATUS == 0 )); then
    exit 1
  fi
  exit "$CREATE_DMG_STATUS"
fi

echo "built: $OUT_FILE"
