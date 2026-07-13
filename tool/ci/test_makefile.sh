#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MACOS="$(make -n package-macos VERSION=1.2.3+45 OUT_DIR=dist)"
LINUX="$(make -n package-linux VERSION=1.2.3+45 OUT_DIR=dist)"
WINDOWS="$(make -n package-windows VERSION=1.2.3+45 MSI_VERSION=1.2.45 OUT_DIR=dist)"

[[ "$MACOS" == *'packaging/macos/build-dmg.sh'* ]]
[[ "$LINUX" == *'packaging/linux/build-deb.sh'* ]]
[[ "$WINDOWS" == *'packaging/windows/build-msi.ps1'* ]]

if grep -Eq 'create-dmg|dpkg-deb|wix build' Makefile; then
  echo 'Makefile contains packaging implementation details' >&2
  exit 1
fi

printf 'Makefile entry-point tests passed\n'
