#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="$SCRIPT_DIR/build-dmg.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/Mirrorstages.app" "$TMP_DIR/bin" "$TMP_DIR/out"
ARGS_LOG="$TMP_DIR/args.log"

cat > "$TMP_DIR/bin/create-dmg" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '<%s>\n' "$@" > "$ARGS_LOG"
args=("$@")
count="${#args[@]}"
output="${args[$((count - 2))]}"
staging="${args[$((count - 1))]}"
[[ -d "$staging/Mirrorstages.app" ]]
[[ -f "$staging/README.txt" ]]
if [[ "${SKIP_OUTPUT:-0}" != "1" ]]; then
  touch "$output"
fi
FAKE
chmod +x "$TMP_DIR/bin/create-dmg"

ARGS_LOG="$ARGS_LOG" CREATE_DMG="$TMP_DIR/bin/create-dmg" \
  bash "$BUILDER" '1.2.3+45' "$TMP_DIR/Mirrorstages.app" "$TMP_DIR/out"

ARGS="$(cat "$ARGS_LOG")"
if [[ "$ARGS" == *'<--overwrite>'* ]]; then
  printf 'create-dmg must not receive unsupported --overwrite option\n%s\n' "$ARGS" >&2
  exit 1
fi

for expected in \
  '<--background>' \
  "<$SCRIPT_DIR/background.png>" \
  '<--window-size>' \
  '<700>' \
  '<520>' \
  '<Mirrorstages.app>' \
  '<225>' \
  '<315>' \
  '<README.txt>' \
  '<360>' \
  '<110>' \
  '<--app-drop-link>' \
  '<445>'; do
  if [[ "$ARGS" != *"$expected"* ]]; then
    printf 'missing create-dmg argument %s\n%s\n' "$expected" "$ARGS" >&2
    exit 1
  fi
done

test -f "$TMP_DIR/out/MirrorStages-Desktop-1.2.3+45-macos.dmg"

if ARGS_LOG="$ARGS_LOG" CREATE_DMG="$TMP_DIR/bin/create-dmg" SKIP_OUTPUT=1 \
  bash "$BUILDER" '1.2.3+46' "$TMP_DIR/Mirrorstages.app" "$TMP_DIR/out" \
  >/dev/null 2>&1; then
  echo 'expected failure when create-dmg produces no output' >&2
  exit 1
fi

printf 'build-dmg tests passed\n'
