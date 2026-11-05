#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

contains_test_framework_import() {
  local directory file line
  for directory in "$@"; do
    [[ -d "$directory" ]] || continue
    while IFS= read -r -d '' file; do
      while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
          "import Testing" | "import XCTest") return 0 ;;
        esac
      done <"$file"
    done < <(find "$directory" -type f -name '*.swift' -print0)
  done
  return 1
}

if contains_test_framework_import Sources/PremiseCore Sources/PremiseStrategies \
  Sources/PremiseMacrosPlugin Sources/PremiseMacros; then
  printf 'boundary validation failed: test framework imports are not allowed in core, strategy or macro source targets\n' >&2
  exit 1
fi

swift package dump-package | python3 -c '
import json
import sys

package = json.load(sys.stdin)
products = {product["name"]: product for product in package["products"]}
for name in ("PremiseCore", "PremiseStrategies", "PremiseDatabase", "PremiseTesting", "PremiseXCTest"):
    product = products.get(name)
    if product is None or "library" not in product["type"] or product["targets"] != [name]:
        sys.exit(f"boundary validation failed: missing required library product {name}")
targets = {target["name"]: target for target in package["targets"]}
required = {
    "PremiseStrategies": {"PremiseCore"},
    "PremiseDatabase": {"PremiseCore", "PremiseSQLite"},
    "PremiseSQLite": {"CSQLite"},
    "PremiseTesting": {"PremiseCore", "PremiseStrategies", "PremiseDatabase"},
    "PremiseXCTest": {"PremiseCore", "PremiseStrategies", "PremiseDatabase"},
}
for name, expected in required.items():
    target = targets.get(name)
    if target is None:
        sys.exit(f"boundary validation failed: missing required target {name}")
    dependencies = target["dependencies"]
    if any(set(dependency) - {"byName", "target"} for dependency in dependencies):
        sys.exit(f"boundary validation failed: unexpected dependency kind in {name}")
    actual = {next(iter(dependency.values()))[0] for dependency in dependencies}
    if actual != expected or len(dependencies) != len(expected):
        sys.exit(f"boundary validation failed: incorrect dependency set for {name}")
if targets["PremiseSQLite"]["dependencies"] != [{"target": ["CSQLite", {"platformNames": ["linux"]}]}]:
    sys.exit("boundary validation failed: CSQLite must be limited to Linux")
'
printf 'boundary validation passed\n'
