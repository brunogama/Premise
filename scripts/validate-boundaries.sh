#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
  printf 'boundary validation failed: %s\n' "$1" >&2
  exit 1
}

core_strategy_sources=(Sources/PremiseCore Sources/PremiseStrategies)

if rg -n --glob '*.swift' '^import (Testing|XCTest)$' "${core_strategy_sources[@]}" >/dev/null; then
  fail "test framework imports are not allowed in Sources/PremiseCore or Sources/PremiseStrategies"
fi

# Macro targets must not import test frameworks either.
if [[ -d Sources/PremiseMacrosPlugin ]] && rg -n '^import (Testing|XCTest)$' Sources/PremiseMacrosPlugin >/dev/null 2>&1; then
  fail "test framework imports are not allowed in Sources/PremiseMacrosPlugin"
fi
if [[ -d Sources/PremiseMacros ]] && rg -n '^import (Testing|XCTest)$' Sources/PremiseMacros >/dev/null 2>&1; then
  fail "test framework imports are not allowed in Sources/PremiseMacros"
fi

# Inspect the resolved package graph rather than the manifest's source spelling.
swift package dump-package | python3 -c '
import json
import sys

package = json.load(sys.stdin)
products = {product["name"]: product for product in package["products"]}
for name in ("PremiseCore", "PremiseStrategies", "PremiseDatabase", "PremiseTesting", "PremiseXCTest"):
    product = products.get(name)
    if product is None or "library" not in product["type"] or product["targets"] != [name]:
        sys.exit(f"boundary validation failed: missing required library product {name}")
'
if ! rg -U 'name: "PremiseStrategies",[[:space:]\n]+dependencies: \["PremiseCore"\]' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseStrategies -> PremiseCore dependency edge'
fi

if ! rg -U 'name: "PremiseDatabase",[[:space:]\n]+dependencies: \["PremiseCore"\]' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseDatabase -> PremiseCore dependency edge'
fi

if ! rg -U 'name: "PremiseTesting",[[:space:]\n]+dependencies: \[[^]]*"PremiseCore"[^]]*"PremiseStrategies"[^]]*"PremiseDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseTesting dependency set'
fi

if ! rg -U 'name: "PremiseXCTest",[[:space:]\n]+dependencies: \[[^]]*"PremiseCore"[^]]*"PremiseStrategies"[^]]*"PremiseDatabase"' Package.swift >/dev/null; then
  fail 'Package.swift is missing the PremiseXCTest dependency set'
fi

printf 'boundary validation passed\n'
