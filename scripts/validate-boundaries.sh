#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'boundary validation failed: %s\n' "$1" >&2
  exit 1
}

core_strategy_sources=(
  Sources/PremiseCore/*.swift
  Sources/PremiseStrategies/*.swift
)

if rg -n '^import (Testing|XCTest)$' "${core_strategy_sources[@]}" >/dev/null; then
  fail "test framework imports are not allowed in Sources/PremiseCore or Sources/PremiseStrategies"
fi

# Macro targets must not import test frameworks either.
if [[ -d Sources/PremiseMacrosPlugin ]] && rg -n '^import (Testing|XCTest)$' Sources/PremiseMacrosPlugin >/dev/null 2>&1; then
  fail "test framework imports are not allowed in Sources/PremiseMacrosPlugin"
fi
if [[ -d Sources/PremiseMacros ]] && rg -n '^import (Testing|XCTest)$' Sources/PremiseMacros >/dev/null 2>&1; then
  fail "test framework imports are not allowed in Sources/PremiseMacros"
fi

required_literals=(
  '.library(name: "PremiseCore", targets: ["PremiseCore"])'
  '.library(name: "PremiseStrategies", targets: ["PremiseStrategies"])'
  '.library(name: "PremiseDatabase", targets: ["PremiseDatabase"])'
  '.library(name: "PremiseTesting", targets: ["PremiseTesting"])'
  '.library(name: "PremiseXCTest", targets: ["PremiseXCTest"])'
  '.library(name: "PremiseMacros", targets: ["PremiseMacros"])'
)

for literal in "${required_literals[@]}"; do
  if ! rg -F "$literal" Package.swift >/dev/null; then
    fail "Package.swift is missing required declaration: $literal"
  fi
done

if ! rg -U 'name: "PremiseStrategies",[[:space:]\n]+dependencies: \["PremiseCore"\]' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseStrategies -> PremiseCore dependency edge'
fi

if ! rg -U 'name: "PremiseDatabase",[[:space:]\n]+dependencies: \[[[:space:]\n]*"PremiseCore",[[:space:]\n]*\.target\(name: "CSQLite", condition: \.when\(platforms: \[\.linux\]\)\),[[:space:]\n]*\]' Package.swift >/dev/null; then
  fail 'PremiseDatabase must depend on exactly PremiseCore plus the Linux-only CSQLite shim'
fi

if ! rg -U 'name: "PremiseTesting",[[:space:]\n]+dependencies: \[[^]]*"PremiseCore"[^]]*"PremiseStrategies"[^]]*"PremiseDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseTesting dependency set'
fi

if ! rg -U 'name: "PremiseXCTest",[[:space:]\n]+dependencies: \[[^]]*"PremiseCore"[^]]*"PremiseStrategies"[^]]*"PremiseDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseXCTest dependency set'
fi

printf 'boundary validation passed\n'
