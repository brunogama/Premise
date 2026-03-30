#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'boundary validation failed: %s\n' "$1" >&2
  exit 1
}

if rg -n '^import (Testing|XCTest)$' Sources/ConjectureCore Sources/ConjectureStrategies >/dev/null; then
  fail "test framework imports are not allowed in Sources/ConjectureCore or Sources/ConjectureStrategies"
fi

required_literals=(
  '.library(name: "ConjectureCore", targets: ["ConjectureCore"])'
  '.library(name: "ConjectureStrategies", targets: ["ConjectureStrategies"])'
  '.library(name: "ConjectureDatabase", targets: ["ConjectureDatabase"])'
  '.library(name: "ConjectureTesting", targets: ["ConjectureTesting"])'
  '.library(name: "ConjectureXCTest", targets: ["ConjectureXCTest"])'
)

for literal in "${required_literals[@]}"; do
  if ! rg -F "$literal" Package.swift >/dev/null; then
    fail "Package.swift is missing required declaration: $literal"
  fi
done

if ! rg -U 'name: "ConjectureStrategies",[[:space:]\n]+dependencies: \["ConjectureCore"\]' Package.swift >/dev/null; then
  fail 'Package.swift is missing the ConjectureStrategies -> ConjectureCore dependency edge'
fi

if ! rg -U 'name: "ConjectureDatabase",[[:space:]\n]+dependencies: \["ConjectureCore"\]' Package.swift >/dev/null; then
  fail 'Package.swift is missing the ConjectureDatabase -> ConjectureCore dependency edge'
fi

if ! rg -U 'name: "ConjectureTesting",[[:space:]\n]+dependencies: \[[^]]*"ConjectureCore"[^]]*"ConjectureStrategies"[^]]*"ConjectureDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the ConjectureTesting dependency set'
fi

if ! rg -U 'name: "ConjectureXCTest",[[:space:]\n]+dependencies: \[[^]]*"ConjectureCore"[^]]*"ConjectureStrategies"[^]]*"ConjectureDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the ConjectureXCTest dependency set'
fi

printf 'boundary validation passed\n'
