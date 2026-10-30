#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
output="${1:-$root/.build/Premise.doccarchive}"
if [[ -e "$output" ]]; then
  echo "Documentation output already exists: $output" >&2
  exit 1
fi
mkdir -p "$root/.build"
work="$(mktemp -d "$root/.build/docc-build.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT

swift build --disable-default-traits -Xswiftc -warnings-as-errors
bin_path="$(swift build --disable-default-traits --show-bin-path)"
target="$(swift -print-target-info | python3 -c 'import json, sys; print(json.load(sys.stdin)["target"]["triple"])')"
sdk="$(xcrun --show-sdk-path)"
frameworks="$(xcrun --show-sdk-platform-path)/Developer/Library/Frameworks"
mkdir -p "$work/all-symbols"
for module in PremiseCore PremiseDatabase PremiseParallel PremiseTelemetry PremiseStrategies PremiseTesting; do
  xcrun swift-symbolgraph-extract -module-name "$module" \
    -I "$bin_path" -I "$bin_path/Modules" -F "$frameworks" \
    -sdk "$sdk" -target "$target" -output-dir "$work/all-symbols"
done
mkdir -p "$work/core-symbols"
cp "$work/all-symbols/PremiseCore.symbols.json" "$work/core-symbols/"
cp "$work/all-symbols/PremiseStrategies@PremiseCore.symbols.json" "$work/core-symbols/"

xcrun docc convert --additional-symbol-graph-dir "$work/core-symbols" \
  --fallback-display-name PremiseCore --fallback-bundle-identifier premisecore \
  --enable-experimental-external-link-support --warnings-as-errors \
  --output-path "$work/core-dependency.doccarchive"

for module in PremiseDatabase PremiseParallel PremiseTelemetry PremiseStrategies PremiseTesting; do
  symbols="$work/symbols-$module"
  mkdir -p "$symbols"
  cp "$work/all-symbols/$module.symbols.json" "$symbols/"
  dependencies=(--dependency "$work/core-dependency.doccarchive")
  if [[ "$module" != PremiseDatabase ]]; then
    dependencies+=(--dependency "$work/PremiseDatabase.doccarchive")
  fi
  xcrun docc convert --additional-symbol-graph-dir "$symbols" \
    "${dependencies[@]}" --fallback-display-name "$module" \
    --fallback-bundle-identifier "$(printf '%s' "$module" | tr '[:upper:]' '[:lower:]')" \
    --enable-experimental-external-link-support --warnings-as-errors \
    --output-path "$work/$module.doccarchive"
done

xcrun docc convert docs/Documentation.docc --additional-symbol-graph-dir "$work/core-symbols" \
  --dependency "$work/PremiseDatabase.doccarchive" \
  --dependency "$work/PremiseParallel.doccarchive" \
  --dependency "$work/PremiseTelemetry.doccarchive" \
  --dependency "$work/PremiseStrategies.doccarchive" \
  --dependency "$work/PremiseTesting.doccarchive" \
  --enable-experimental-external-link-support --warnings-as-errors \
  --output-path "$work/PremiseCore.doccarchive"
xcrun docc merge "$work/PremiseCore.doccarchive" "$work/PremiseDatabase.doccarchive" \
  "$work/PremiseParallel.doccarchive" "$work/PremiseTelemetry.doccarchive" \
  "$work/PremiseStrategies.doccarchive" "$work/PremiseTesting.doccarchive" \
  --output-path "$output"
test -s "$output/data/tutorials/documentation/paralleltesting.json"
test -s "$output/data/documentation/documentation/paralleltesting.json"
echo "Built warning-free documentation: $output"
