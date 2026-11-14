#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="$(mktemp "${TMPDIR:-/tmp}/beside-check.XXXXXX")"
trap 'rm -f "$BINARY"' EXIT
swiftc -swift-version 6 -parse-as-library -o "$BINARY" \
  "$ROOT/aaltodepression/Engine/Contracts/EverydayContracts.swift" \
  "$ROOT/aaltodepression/Store/EverydayStore.swift" \
  "$ROOT/Tools/EverydayCheck/main.swift"
"$BINARY"
