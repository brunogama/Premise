#!/usr/bin/env bash
# Build PremiseCore and PremiseStrategies for one Apple simulator destination
# and prove that target-specific Swift modules were produced.

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/validate-apple-destination.sh <platform> [derived-data-path]

Platforms:
  iOS Simulator
  watchOS Simulator
  tvOS Simulator
  visionOS Simulator
USAGE
  exit 2
}

fail() {
  echo "error: $*" >&2
  exit 1
}

platform="${1:-}"
case "$platform" in
  "iOS Simulator")
    slug="ios"
    product_directory="Debug-iphonesimulator"
    triple_suffix="apple-ios-simulator"
    ;;
  "watchOS Simulator")
    slug="watchos"
    product_directory="Debug-watchsimulator"
    triple_suffix="apple-watchos-simulator"
    ;;
  "tvOS Simulator")
    slug="tvos"
    product_directory="Debug-appletvsimulator"
    triple_suffix="apple-tvos-simulator"
    ;;
  "visionOS Simulator")
    slug="visionos"
    product_directory="Debug-xrsimulator"
    triple_suffix="apple-xros-simulator"
    ;;
  *) usage ;;
esac

derived_data_path="${2:-.build/apple-destinations/$slug}"
[[ ! -e "$derived_data_path" ]] \
  || fail "derived data path already exists: $derived_data_path"

printf 'command: xcodebuild build -scheme PremiseStrategies -destination generic/platform=%s\n' \
  "$platform"

xcodebuild build \
  -skipMacroValidation \
  -scheme PremiseStrategies \
  -destination "generic/platform=$platform" \
  -derivedDataPath "$derived_data_path" \
  CODE_SIGNING_ALLOWED=NO

shopt -s nullglob
for module in PremiseCore PremiseStrategies; do
  artifacts=(
    "$derived_data_path/Build/Products/$product_directory/$module.swiftmodule/"*"-$triple_suffix.swiftmodule"
  )
  ((${#artifacts[@]} > 0)) \
    || fail "$module produced no $triple_suffix Swift module"
  printf 'validated: %s\n' "${artifacts[@]}"
done
