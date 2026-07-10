#!/usr/bin/env bash
# 从 Shorebird/Flutter 的 Linux 构建产物打一个 .deb 安装包。
#
# 用法: build-deb.sh <version> <bundle_dir> <icon_png> <out_dir>
#   version    如 1.0.0
#   bundle_dir Flutter 产物目录，含可执行文件 desktop、lib/、data/
#              （通常是 build/linux/x64/release/bundle）
#   icon_png   256x256 的 PNG 图标
#   out_dir    输出目录
set -euo pipefail

VERSION="${1:?version required}"
BUNDLE_DIR="${2:?bundle dir required}"
ICON_PNG="${3:?icon png required}"
OUT_DIR="${4:?out dir required}"

PKG="mirrorstages-desktop"
BIN="desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

INSTALL_DIR="$ROOT/opt/$PKG"
mkdir -p "$INSTALL_DIR" "$ROOT/DEBIAN" \
         "$ROOT/usr/bin" \
         "$ROOT/usr/share/applications" \
         "$ROOT/usr/share/icons/hicolor/256x256/apps"

# 复制应用本体
cp -r "$BUNDLE_DIR"/. "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BIN"

# /usr/bin 里放一个软链，方便命令行启动
ln -s "/opt/$PKG/$BIN" "$ROOT/usr/bin/$PKG"

# 桌面入口与图标
cp "$SCRIPT_DIR/$PKG.desktop" "$ROOT/usr/share/applications/$PKG.desktop"
cp "$ICON_PNG" "$ROOT/usr/share/icons/hicolor/256x256/apps/$PKG.png"

# 计算安装体积（KB），写进 control
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
Description: Mirrorstages client
 Mirrorstages desktop client.
EOF

mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/${PKG}_${VERSION}_amd64.deb"
dpkg-deb --build --root-owner-group "$ROOT" "$OUT_FILE"
echo "built: $OUT_FILE"
