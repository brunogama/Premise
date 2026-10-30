#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

for mode in default source binary; do
  case "$mode" in
    default) manifest=$(env -u PREMISE_MACRO_SOURCE -u PREMISE_MACRO_BINARY swift package dump-package) ;;
    source) manifest=$(env -u PREMISE_MACRO_BINARY PREMISE_MACRO_SOURCE=1 swift package dump-package) ;;
    binary) manifest=$(env -u PREMISE_MACRO_SOURCE PREMISE_MACRO_BINARY=1 PREMISE_MACRO_BINARY_CHECKSUM=unused swift package dump-package) ;;
  esac
  printf '%s' "$manifest" | python3 -c '
import json, sys
package = json.load(sys.stdin)
names = {entry["name"] for key in ("products", "targets") for entry in package[key]}
excluded = {"PremiseMacros", "PremiseMacrosPlugin"} & names
if excluded:
    sys.exit("macro targets or products unexpectedly present: " + ", ".join(sorted(excluded)))
if package["dependencies"]:
    sys.exit("unexpected package dependencies")
'
done

# The retained artifact script must fail before touching existing artifacts.
fixture=$(mktemp -d "${TMPDIR:-/tmp}/premise-macro-guard.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/.build/artifacts/PremiseMacrosPlugin.artifactbundle" "$fixture/bin"
cp scripts/build-macro-artifact.sh "$fixture/scripts/"
printf 'keep\n' > "$fixture/.build/artifacts/PremiseMacrosPlugin.artifactbundle/sentinel"
printf 'keep\n' > "$fixture/.build/artifacts/PremiseMacrosPlugin.artifactbundle.zip"
printf '#!/bin/sh\nprintf "{\\"targets\\": []}\\n"\n' > "$fixture/bin/swift"
chmod +x "$fixture/bin/swift"
if PATH="$fixture/bin:$PATH" bash "$fixture/scripts/build-macro-artifact.sh" > "$fixture/output" 2>&1; then
  printf 'artifact build unexpectedly succeeded\n' >&2
  exit 1
fi
if ! [ -f "$fixture/.build/artifacts/PremiseMacrosPlugin.artifactbundle/sentinel" ] ||
  ! [ -f "$fixture/.build/artifacts/PremiseMacrosPlugin.artifactbundle.zip" ]; then
  printf 'artifact build removed existing artifacts\n' >&2
  exit 1
fi
if ! grep -Fq 'macro artifacts are unavailable in this version' "$fixture/output"; then
  printf 'artifact build did not explain macro exclusion\n' >&2
  exit 1
fi
printf 'macro exclusion verified\n'
