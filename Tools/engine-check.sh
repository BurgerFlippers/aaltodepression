#!/bin/sh
# Compiles the pure-Swift engine (all of Engine/, no SwiftUI) with the demo sources and runs the checks:
# the 60-day step-engine table and the daily planner scenarios.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/engine-check"
# shellcheck disable=SC2046
swiftc -swift-version 6 -O -o "$OUT" \
  $(find "$ROOT/aaltodepression/Engine" -name '*.swift' | sort) \
  "$ROOT"/aaltodepression/Sources/DemoSource.swift \
  $(ls "$ROOT"/aaltodepression/Sources/DemoPlannerSource.swift 2>/dev/null) \
  $(find "$ROOT/Tools/EngineCheck" -name '*.swift' | sort)
"$OUT" "$ROOT/aaltodepression/Resources/plan_perttu.json"
