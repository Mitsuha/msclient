#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?version required}"
BUNDLE_DIR="${2:?bundle dir required}"
ICON_PNG="${3:?icon png required}"
OUT_DIR="${4:?out dir required}"

PKG="mirrorstages-desktop"
BIN="desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -x "$BUNDLE_DIR/$BIN" ]]; then
  echo "error: bundle executable not found or not executable: $BUNDLE_DIR/$BIN" >&2
  exit 1
fi

if [[ ! -f "$ICON_PNG" ]]; then
  echo "error: icon not found: $ICON_PNG" >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "error: dpkg-deb is required" >&2
  exit 1
fi

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

INSTALL_DIR="$ROOT/opt/$PKG"
mkdir -p \
  "$INSTALL_DIR" \
  "$ROOT/DEBIAN" \
  "$ROOT/usr/bin" \
  "$ROOT/usr/share/applications" \
  "$ROOT/usr/share/icons/hicolor/256x256/apps"

cp -R "$BUNDLE_DIR"/. "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BIN"
ln -s "/opt/$PKG/$BIN" "$ROOT/usr/bin/$PKG"
cp "$SCRIPT_DIR/$PKG.desktop" "$ROOT/usr/share/applications/$PKG.desktop"
cp "$ICON_PNG" "$ROOT/usr/share/icons/hicolor/256x256/apps/$PKG.png"

INSTALLED_SIZE="$(du -ks "$INSTALL_DIR" | cut -f1)"
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Maintainer: MirrorStages <dev@mirrorstages.com>
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0, libayatana-appindicator3-1, libblkid1, liblzma5
Description: Mirrorstages desktop client
 Mirrorstages desktop client.
EOF

mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/${PKG}_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$ROOT" "$OUT_FILE"
echo "built: $OUT_FILE"
