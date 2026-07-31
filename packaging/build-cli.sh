#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <out-dir>" >&2
  exit 2
fi

VERSION="$1"
OUT_DIR="$2"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_DIR="$ROOT/cli"
MANIFEST="$ROOT/version.json"

# The CLI is versioned separately from the desktop app: the binary compares
# itself against cli_version in the published manifest, so that is what must be
# embedded. Older manifests without the key fall back to the release version.
CLI_VERSION="$(
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); print(m.get("cli_version") or m.get("version") or "")' \
    "$MANIFEST"
)"
CLI_VERSION="${CLI_VERSION:-$VERSION}"

# SYSTEM suffixes published to CNB as latest/cli/mstages-<system>.
TARGETS=(
  "darwin arm64"
  "linux amd64"
)

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

for target in "${TARGETS[@]}"; do
  read -r goos goarch <<<"$target"
  output="$OUT_DIR/mstages-$goos-$goarch"
  echo "building $output for MirrorStages CLI $CLI_VERSION (release $VERSION)"
  (
    cd "$CLI_DIR"
    # Without an embedded version the self-updater stays off, so a plain
    # `go build` can never be replaced by a published release.
    CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" \
      go build \
        -trimpath \
        -ldflags "-s -w -X github.com/mirrorstages/mstages/internal/app.Version=$CLI_VERSION" \
        -o "$output" \
        ./cmd/mstages
  )
  chmod 0755 "$output"
done
