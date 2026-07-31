#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
MANIFEST="${2:-version.json}"

if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version> [manifest]" >&2
  exit 2
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "error: update manifest not found: $MANIFEST" >&2
  exit 1
fi

if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$MANIFEST"; then
  echo "error: update manifest is not valid JSON: $MANIFEST" >&2
  exit 1
fi

MANIFEST_VERSION="$(
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' \
    "$MANIFEST"
)"

if [[ "$MANIFEST_VERSION" != "$VERSION" ]]; then
  echo "error: $MANIFEST version $MANIFEST_VERSION does not match release version $VERSION" >&2
  echo "hint: bump \"version\" in $MANIFEST before tagging" >&2
  exit 1
fi

for key in forced download_page auth_download; do
  if ! python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])) else 1)' \
    "$MANIFEST" "$key"; then
    echo "error: $MANIFEST is missing required key: $key" >&2
    exit 1
  fi
done

# cli_version is intentionally allowed to differ from the release version — the
# CLI ships on its own cadence — but it must be present, because that is what
# packaging/build-cli.sh embeds and what the binary compares itself against.
for key in cli_version cli_forced cli_download; do
  if ! python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])) else 1)' \
    "$MANIFEST" "$key"; then
    echo "error: $MANIFEST is missing required key: $key" >&2
    exit 1
  fi
done

# The CLI self-updater looks itself up in cli_download by "<goos>-<goarch>";
# a missing entry would make every launch of that platform's binary report a
# failed update.
for system in darwin-arm64 linux-amd64; do
  if ! python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("cli_download",{}).get(sys.argv[2]) else 1)' \
    "$MANIFEST" "$system"; then
    echo "error: $MANIFEST is missing cli_download entry: $system" >&2
    exit 1
  fi
done

printf 'update manifest %s matches release version %s\n' "$MANIFEST" "$VERSION"
