#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'boundary validation failed: %s\n' "$1" >&2
  exit 1
}

contains_test_framework_import() {
  local file line
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        "import Testing" | "import XCTest") return 0 ;;
      esac
    done <"$file"
  done
  return 1
}

core_strategy_sources=(
  Sources/PremiseCore/*.swift
  Sources/PremiseStrategies/*.swift
)

if contains_test_framework_import "${core_strategy_sources[@]}"; then
  fail "test framework imports are not allowed in Sources/PremiseCore or Sources/PremiseStrategies"
fi

macro_sources=(
  Sources/PremiseMacrosPlugin/*.swift
  Sources/PremiseMacros/*.swift
)
if contains_test_framework_import "${macro_sources[@]}"; then
  fail "test framework imports are not allowed in macro source targets"
fi

package_manifest="$(<Package.swift)"
required_literals=(
  '.library(name: "PremiseCore", targets: ["PremiseCore"])'
  '.library(name: "PremiseStrategies", targets: ["PremiseStrategies"])'
  '.library(name: "PremiseDatabase", targets: ["PremiseDatabase"])'
  '.library(name: "PremiseTesting", targets: ["PremiseTesting"])'
  '.library(name: "PremiseXCTest", targets: ["PremiseXCTest"])'
  '.library(name: "PremiseMacros", targets: ["PremiseMacros"])'
)

for literal in "${required_literals[@]}"; do
  [[ "$package_manifest" == *"$literal"* ]] \
    || fail "Package.swift is missing required declaration: $literal"
done

required_fragments=(
  $'name: "PremiseStrategies",\n      dependencies: ["PremiseCore"]'
  $'name: "PremiseDatabase",\n      dependencies: ["PremiseCore", "PremiseSQLite"]'
  $'name: "PremiseSQLite",\n      dependencies: [\n        .target(name: "CSQLite", condition: .when(platforms: [.linux]))\n      ]'
  $'name: "PremiseTesting",\n      dependencies: [\n        "PremiseCore",\n        "PremiseStrategies",\n        "PremiseDatabase",\n      ]'
  $'name: "PremiseXCTest",\n      dependencies: [\n        "PremiseCore",\n        "PremiseStrategies",\n        "PremiseDatabase",\n      ]'
)
fragment_descriptions=(
  "PremiseStrategies -> PremiseCore dependency edge"
  "PremiseDatabase exact dependency set"
  "PremiseSQLite exact dependency set"
  "PremiseTesting dependency set"
  "PremiseXCTest dependency set"
)

for index in "${!required_fragments[@]}"; do
  [[ "$package_manifest" == *"${required_fragments[$index]}"* ]] \
    || fail "Package.swift is missing ${fragment_descriptions[$index]}"
done

printf 'boundary validation passed\n'
