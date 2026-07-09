#!/usr/bin/env bash
# 从 Shorebird/Flutter 的 Linux 构建产物打一个 AppImage。
#
# 用法: build-appimage.sh <version> <bundle_dir> <icon_png> <out_dir>
# 依赖: appimagetool（脚本会自动下载到临时目录）
set -euo pipefail

VERSION="${1:?version required}"
BUNDLE_DIR="${2:?bundle dir required}"
ICON_PNG="${3:?icon png required}"
OUT_DIR="${4:?out dir required}"

PKG="mirrorstages-desktop"
BIN="desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APPDIR="$WORK/AppDir"
mkdir -p "$APPDIR/usr/bin"

# 应用本体放到 usr/bin
cp -r "$BUNDLE_DIR"/. "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/$BIN"

# 顶层图标 + .desktop（AppImage 规范要求二者都在 AppDir 根）
cp "$ICON_PNG" "$APPDIR/$PKG.png"
cp "$SCRIPT_DIR/$PKG.desktop" "$APPDIR/$PKG.desktop"

# AppRun 启动脚本
cat > "$APPDIR/AppRun" <<EOF
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/$BIN" "\$@"
EOF
chmod +x "$APPDIR/AppRun"

# 下载 appimagetool（无需 FUSE，用 --appimage-extract-and-run 运行）
TOOL="$WORK/appimagetool.AppImage"
curl -fsSL -o "$TOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x "$TOOL"

mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/MirrorStages-Desktop-${VERSION}-x86_64.AppImage"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUT_FILE"
echo "built: $OUT_FILE"
