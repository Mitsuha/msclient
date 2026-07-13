#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="$SCRIPT_DIR/build-deb.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_failure_contains() {
  local expected="$1"
  shift
  local output

  if output="$(bash "$BUILDER" "$@" 2>&1)"; then
    echo "expected build-deb.sh to fail" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    printf 'expected error containing: %s\nactual: %s\n' "$expected" "$output" >&2
    exit 1
  fi
}

assert_failure_contains 'version required'

mkdir -p "$TMP_DIR/bundle" "$TMP_DIR/out"
printf 'not executable\n' > "$TMP_DIR/bundle/desktop"
printf 'png\n' > "$TMP_DIR/icon.png"
assert_failure_contains 'bundle executable not found or not executable' \
  '1.2.3+45' "$TMP_DIR/bundle" "$TMP_DIR/icon.png" "$TMP_DIR/out"

chmod +x "$TMP_DIR/bundle/desktop"
assert_failure_contains 'icon not found' \
  '1.2.3+45' "$TMP_DIR/bundle" "$TMP_DIR/missing.png" "$TMP_DIR/out"

printf 'build-deb validation tests passed\n'
