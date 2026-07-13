#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVER="$SCRIPT_DIR/resolve_tag.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PUBSPEC="$TMP_DIR/pubspec.yaml"

write_version() {
  printf 'name: fixture\nversion: %s\n' "$1" > "$PUBSPEC"
}

assert_output() {
  local kind="$1"
  local tag="$2"
  local expected="$3"
  local actual

  actual="$(bash "$RESOLVER" "$kind" "$tag" "$PUBSPEC")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

assert_failure() {
  if bash "$RESOLVER" "$@" "$PUBSPEC" >/dev/null 2>&1; then
    printf 'expected failure: %s\n' "$*" >&2
    exit 1
  fi
}

write_version '1.2.3+45'
assert_output release 'v1.2.3+45' $'version=1.2.3+45\nmsi_version=1.2.45'
assert_output patch 'v1.2.3+45-patch.1' $'version=1.2.3+45\nmsi_version=1.2.45\npatch_sequence=1'

assert_failure release 'v1.2.3'
assert_failure release 'v1.2.3+45-patch.1'
assert_failure patch 'v1.2.3+45'
assert_failure patch 'v1.2.3+45-patch.0'
assert_failure unknown 'v1.2.3+45'

write_version '1.2.3+46'
assert_failure release 'v1.2.3+45'

write_version '256.2.3+45'
assert_failure release 'v256.2.3+45'

write_version '1.256.3+45'
assert_failure release 'v1.256.3+45'

write_version '1.2.3+65536'
assert_failure release 'v1.2.3+65536'

printf 'resolve_tag tests passed\n'
