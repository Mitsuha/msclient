#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <version> <artifacts-dir> [version-manifest]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$1"
ARTIFACTS_DIR="$(cd "$2" && pwd)"
MANIFEST="${3:-$ROOT/version.json}"
REPOSITORY_URL="https://cnb.cool/mirrorstages/gost.git"
CHECKOUT_DIR="cnb-release"

# The update manifest lives in this repository; CI only validates and copies it.
bash "$ROOT/tool/ci/check_version_manifest.sh" "$VERSION" "$MANIFEST"

CLI_BINARIES=(
  mstages-darwin-arm64
  mstages-linux-amd64
)

for binary in "${CLI_BINARIES[@]}"; do
  if [[ ! -f "$ARTIFACTS_DIR/$binary" ]]; then
    echo "error: missing CLI artifact: $ARTIFACTS_DIR/$binary" >&2
    exit 1
  fi
done

git clone --depth 1 "$REPOSITORY_URL" "$CHECKOUT_DIR"
install -d "$CHECKOUT_DIR/latest"
install -m 0644 \
  "$ARTIFACTS_DIR/mirrorstages-desktop_${VERSION}_amd64.deb" \
  "$CHECKOUT_DIR/latest/mirrorstages.deb"
install -m 0644 \
  "$ARTIFACTS_DIR/MirrorStages-Desktop-${VERSION}-macos.dmg" \
  "$CHECKOUT_DIR/latest/mirrorstages.dmg"
install -m 0644 \
  "$ARTIFACTS_DIR/MirrorStages-Desktop-${VERSION}-windows-x64.msi" \
  "$CHECKOUT_DIR/latest/mirrorstages.msi"

# Artifact downloads drop the executable bit; restore it on the way in.
install -d "$CHECKOUT_DIR/latest/cli"
for binary in "${CLI_BINARIES[@]}"; do
  install -m 0755 "$ARTIFACTS_DIR/$binary" "$CHECKOUT_DIR/latest/cli/$binary"
done

install -m 0644 "$MANIFEST" "$CHECKOUT_DIR/latest/version.json"
install -m 0755 "$ROOT/packaging/install.sh" "$CHECKOUT_DIR/latest/install.sh"

git -C "$CHECKOUT_DIR" config user.name github-actions[bot]
git -C "$CHECKOUT_DIR" config user.email 41898282+github-actions[bot]@users.noreply.github.com
git -C "$CHECKOUT_DIR" add latest
if git -C "$CHECKOUT_DIR" diff --cached --quiet; then
  echo "CNB release repository is already up to date"
  exit 0
fi

git -C "$CHECKOUT_DIR" commit -m "release: MirrorStages $VERSION"
git -C "$CHECKOUT_DIR" push origin HEAD
