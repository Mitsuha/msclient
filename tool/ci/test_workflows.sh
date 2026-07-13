#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE="$ROOT/.github/workflows/shorebird-release.yml"
PATCH="$ROOT/.github/workflows/shorebird-patch.yml"

test -f "$RELEASE"
test -f "$PATCH"

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

if grep -Eq 'pull_request:|branches:|flutter test|flutter analyze|dart format|action-gh-release|(^|[[:space:]])make[[:space:]]' "$RELEASE" "$PATCH"; then
  echo 'workflow contains a forbidden trigger or command' >&2
  exit 1
fi

if grep -Eq 'allow-native-diffs|allow-asset-diffs|release-version=latest' "$PATCH"; then
  echo 'patch workflow contains an unsafe Shorebird option' >&2
  exit 1
fi

printf 'workflow static tests passed\n'
