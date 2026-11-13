#!/bin/sh
# Compiles the pure-Swift engine with the demo source and prints the 60-day check table.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/engine-check"
swiftc -swift-version 6 -O -o "$OUT" \
  "$ROOT"/aaltodepression/Engine/*.swift \
  "$ROOT"/aaltodepression/Sources/DemoSource.swift \
  "$ROOT"/Tools/EngineCheck/main.swift
"$OUT" "$ROOT/aaltodepression/Resources/plan_perttu.json"
