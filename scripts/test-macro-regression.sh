#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
syntax_root="${SWIFT_SYNTAX_ROOT:-$root/.build/checkouts/swift-syntax}"
if [[ ! -f "$syntax_root/Package.swift" ]]; then
  echo "Set SWIFT_SYNTAX_ROOT to an existing swift-syntax checkout." >&2
  exit 1
fi
syntax_root="$(cd "$syntax_root" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/premise-macro-regression.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp -R "$root/Tests/MacroRegression/." "$work/"
mkdir -p "$work/Sources/PremiseMacrosPlugin" "$work/Sources/PremiseMacros"
cp "$root"/Sources/PremiseMacrosPlugin/*.swift "$work/Sources/PremiseMacrosPlugin/"
cp "$root"/Sources/PremiseMacros/*.swift "$work/Sources/PremiseMacros/"
export PREMISE_ROOT="$root" SWIFT_SYNTAX_ROOT="$syntax_root"
if ! swift test --package-path "$work" --disable-xctest "$@" >"$work/test.log" 2>&1; then
  cat "$work/test.log" >&2
  exit 1
fi
for suite in oneValue_Given fourValues_Given avoidsCapturingGlobals_Given threeValues_Given nested_Given repeat_Given; do
  if ! grep -F "Suite $suite passed" "$work/test.log" >/dev/null; then
    cat "$work/test.log" >&2
    echo "Expected generated suite $suite did not pass." >&2
    exit 1
  fi
done
cp "$work/Invalid/GivenArity.swift" "$work/Tests/PremiseMacroRegressionTests/"
if swift test --package-path "$work" --disable-xctest >"$work/invalid.log" 2>&1; then
  echo "Expected an arity mismatch to fail compilation." >&2
  exit 1
fi
if ! grep -F '@given has 2 strategies but function has 1 parameters' "$work/invalid.log" >/dev/null; then
  cat "$work/invalid.log" >&2
  echo "Expected the macro arity diagnostic." >&2
  exit 1
fi
echo "Macro regression tests passed."
