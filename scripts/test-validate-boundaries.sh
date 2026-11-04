#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/premise-boundaries-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/scripts" "$temporary/Sources/PremiseCore/Nested" \
  "$temporary/Sources/PremiseStrategies/Nested"
cp "$root/scripts/validate-boundaries.sh" "$temporary/scripts/"
cp "$root/Package.swift" "$temporary/"
cp -R "$root/Sources/PremiseCore" "$temporary/Sources/"
cp -R "$root/Sources/PremiseStrategies" "$temporary/Sources/"
rm -rf "$temporary/Sources/PremiseCore/Documentation.docc" "$temporary/Sources/PremiseStrategies/Documentation.docc"

(cd "$temporary" && bash scripts/validate-boundaries.sh) >/dev/null
for module in PremiseCore PremiseStrategies; do
  probe="$temporary/Sources/$module/Nested/BoundaryProbe.swift"
  printf 'import Testing\n' > "$probe"
  if (cd "$temporary" && bash scripts/validate-boundaries.sh) >/dev/null 2>&1; then
    printf 'Nested forbidden import was accepted in %s\n' "$module" >&2
    exit 1
  fi
  rm "$probe"
done
printf 'Boundary validation regression passed.\n'
