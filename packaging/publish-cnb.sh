#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <artifacts-dir>" >&2
  exit 2
fi

VERSION="$1"
ARTIFACTS_DIR="$(cd "$2" && pwd)"
REPOSITORY_URL="https://cnb.cool/mirrorstages/gost.git"
CHECKOUT_DIR="cnb-release"

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

printf '%s\n' \
  '{' \
  "  \"version\": \"$VERSION\"," \
  '  "forced": true,' \
  '  "download_page": "https://mirrorstages.com/app",' \
  '  "auth_download": {' \
  '    "darwin": "https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/mirrorstages.dmg",' \
  '    "windows": "https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/mirrorstages.msi",' \
  '    "linux": "https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/mirrorstages.deb"' \
  '  }' \
  '}' \
  > "$CHECKOUT_DIR/latest/version.json"

git -C "$CHECKOUT_DIR" config user.name github-actions[bot]
git -C "$CHECKOUT_DIR" config user.email 41898282+github-actions[bot]@users.noreply.github.com
git -C "$CHECKOUT_DIR" add latest
if git -C "$CHECKOUT_DIR" diff --cached --quiet; then
  echo "CNB release repository is already up to date"
  exit 0
fi

git -C "$CHECKOUT_DIR" commit -m "release: MirrorStages $VERSION"
git -C "$CHECKOUT_DIR" push origin HEAD
