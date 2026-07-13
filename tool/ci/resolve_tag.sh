#!/usr/bin/env bash
set -euo pipefail

KIND="${1:-}"
TAG="${2:-}"
PUBSPEC="${3:-pubspec.yaml}"

case "$KIND" in
  release)
    PATTERN='^v([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$'
    ;;
  patch)
    PATTERN='^v([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)-patch\.([1-9][0-9]*)$'
    ;;
  *)
    echo "error: kind must be release or patch" >&2
    exit 2
    ;;
esac

if [[ ! "$TAG" =~ $PATTERN ]]; then
  echo "error: invalid $KIND tag: $TAG" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
BUILD="${BASH_REMATCH[4]}"
PATCH_SEQUENCE="${BASH_REMATCH[5]:-}"
VERSION="$MAJOR.$MINOR.$PATCH+$BUILD"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "error: pubspec not found: $PUBSPEC" >&2
  exit 1
fi

PUBSPEC_VERSION="$(
  sed -nE 's/^version:[[:space:]]*([^[:space:]#]+).*$/\1/p' "$PUBSPEC" \
    | tr -d "\"'"
)"

if [[ -z "$PUBSPEC_VERSION" ]]; then
  echo "error: pubspec has no top-level version: $PUBSPEC" >&2
  exit 1
fi

if [[ "$PUBSPEC_VERSION" != "$VERSION" ]]; then
  echo "error: tag version $VERSION does not match pubspec version $PUBSPEC_VERSION" >&2
  exit 1
fi

if (( 10#$MAJOR > 255 || 10#$MINOR > 255 || 10#$BUILD > 65535 )); then
  echo "error: version cannot be represented as an MSI ProductVersion" >&2
  exit 1
fi

printf 'version=%s\n' "$VERSION"
printf 'msi_version=%s.%s.%s\n' "$MAJOR" "$MINOR" "$BUILD"
if [[ "$KIND" == "patch" ]]; then
  printf 'patch_sequence=%s\n' "$PATCH_SEQUENCE"
fi
