#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE="$ROOT/.github/workflows/shorebird-release.yml"
PATCH="$ROOT/.github/workflows/shorebird-patch.yml"
PUBLISH_CNB="$ROOT/packaging/publish-cnb.sh"
MANIFEST="$ROOT/version.json"

test -f "$RELEASE"
test -f "$PATCH"
test -x "$PUBLISH_CNB"

grep -Fq -- "- 'v*'" "$RELEASE"
grep -Fq -- "- '!v*-patch.*'" "$RELEASE"
grep -Fq -- "- 'v*-patch.*'" "$PATCH"
grep -Fq 'contents: read' "$RELEASE"
grep -Fq 'contents: read' "$PATCH"

grep -Fq 'tool/ci/resolve_tag.sh release' "$RELEASE"
grep -Fq 'tool/ci/resolve_tag.sh patch' "$PATCH"
grep -Fq -- '--release-version="$VERSION"' "$PATCH"
grep -Fq -- '--track=stable' "$PATCH"

grep -Fq 'packaging/windows/build-msi.ps1' "$RELEASE"
grep -Fq 'packaging/linux/build-deb.sh' "$RELEASE"
grep -Fq 'packaging/macos/build-dmg.sh' "$RELEASE"
grep -Fq 'retention-days: 7' "$RELEASE"

if grep -Eq 'actions/checkout@v[0-6]|actions/upload-artifact@v[0-6]' "$RELEASE" "$PATCH"; then
  echo 'workflow uses an outdated GitHub-maintained action' >&2
  exit 1
fi
grep -Fq 'actions/checkout@v7' "$RELEASE"
grep -Fq 'actions/checkout@v7' "$PATCH"
grep -Fq 'actions/upload-artifact@v7' "$RELEASE"
grep -Fq 'actions/download-artifact@v7' "$RELEASE"

grep -Fq 'needs: [prepare, windows, linux, macos, cli]' "$RELEASE"
grep -Fq 'secrets.CNB_GIT_CREDENTIALS' "$RELEASE"
grep -Fq 'packaging/publish-cnb.sh "$VERSION" artifacts' "$RELEASE"
grep -Fq 'git clone --depth 1' "$PUBLISH_CNB"
grep -Fq 'latest/mirrorstages.deb' "$PUBLISH_CNB"
grep -Fq 'latest/mirrorstages.dmg' "$PUBLISH_CNB"
grep -Fq 'latest/mirrorstages.msi' "$PUBLISH_CNB"
grep -Fq 'latest/version.json' "$PUBLISH_CNB"
grep -Fq 'latest/cli/' "$PUBLISH_CNB"
grep -Fq 'latest/install.sh' "$PUBLISH_CNB"
bash -n "$PUBLISH_CNB"

# The update manifest is maintained in-repo and copied verbatim by CI.
test -f "$MANIFEST"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$MANIFEST"
grep -Fq '"download_page": "https://mirrorstages.com/app"' "$MANIFEST"
grep -Fq '"auth_download": {' "$MANIFEST"
if grep -Fq 'printf' "$PUBLISH_CNB" && grep -Fq '"auth_download"' "$PUBLISH_CNB"; then
  echo 'publish script still generates version.json instead of copying it' >&2
  exit 1
fi
PUBSPEC_VERSION="$(
  sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*$/\1/p' "$ROOT/pubspec.yaml" \
    | tr -d "\"'"
)"
bash "$ROOT/tool/ci/check_version_manifest.sh" "$PUBSPEC_VERSION" "$MANIFEST" >/dev/null

# The Go CLI ships alongside the desktop installers.
grep -Fq 'packaging/build-cli.sh "$VERSION" dist/cli' "$RELEASE"
grep -Fq 'actions/setup-go@v5' "$RELEASE"
bash -n "$ROOT/packaging/build-cli.sh"
sh -n "$ROOT/packaging/install.sh"
test -x "$ROOT/packaging/install.sh"
# macOS 版没有签名，安装脚本必须自行 ad-hoc 签名。
grep -Fq 'codesign --force --sign -' "$ROOT/packaging/install.sh"
bash -n "$ROOT/tool/ci/check_version_manifest.sh"
test -x "$ROOT/packaging/build-cli.sh"
test -x "$ROOT/tool/ci/check_version_manifest.sh"
grep -Fq '"darwin arm64"' "$ROOT/packaging/build-cli.sh"
grep -Fq '"linux amd64"' "$ROOT/packaging/build-cli.sh"
for system in darwin-arm64 linux-amd64; do
  grep -Fq "mstages-$system" "$PUBLISH_CNB"
  grep -Fq "mstages-$system" "$MANIFEST"
done

if grep -Eq 'pull_request:|branches:|flutter test|flutter analyze|dart format|action-gh-release|(^|[[:space:]])make[[:space:]]' "$RELEASE" "$PATCH"; then
  echo 'workflow contains a forbidden trigger or command' >&2
  exit 1
fi

if grep -Eq 'allow-native-diffs|allow-asset-diffs|release-version=latest' "$PATCH"; then
  echo 'patch workflow contains an unsafe Shorebird option' >&2
  exit 1
fi

printf 'workflow static tests passed\n'
