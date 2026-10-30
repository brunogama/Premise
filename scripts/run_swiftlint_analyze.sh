#!/bin/sh
set -eu

ROOT="$(cd "${1:-.}" && pwd)"
cd "$ROOT"
if ! command -v pkg-config >/dev/null 2>&1 || ! pkg-config --exists z3; then
  echo "SwiftLint analyzer requires pkg-config and z3 development headers." >&2
  exit 1
fi
if [ ! -f "$ROOT/Sources/CZ3/module.modulemap" ]; then
  echo "SwiftLint analyzer requires the CZ3 module map." >&2
  exit 1
fi
mkdir -p "$ROOT/.build"
BUILD_PATH="$(mktemp -d "$ROOT/.build/swiftlint-analyze.XXXXXX")"
trap 'rm -rf "$BUILD_PATH"' EXIT
trap 'exit 1' HUP INT TERM
CFLAGS="$(pkg-config --cflags z3)" || {
  echo "Unable to obtain z3 compiler flags from pkg-config." >&2
  exit 1
}
printf '%s\n' "$CFLAGS" | xargs -n 1 printf '%s\n' > "$BUILD_PATH/z3-cflags.txt"

swift build --build-system native --build-path "$BUILD_PATH"
DESCRIPTION_PATH="$(find "$BUILD_PATH" -path '*/debug/description.json' -print -quit)"
if [ -z "$DESCRIPTION_PATH" ]; then
  echo "SwiftPM build description not found in $BUILD_PATH" >&2
  exit 1
fi
BUILD_DIRECTORY="${DESCRIPTION_PATH%/description.json}"
swift "$ROOT/scripts/write_swiftlint_compile_commands.swift" \
  "$ROOT" "$BUILD_DIRECTORY" "$BUILD_PATH/compile_commands.json" "$BUILD_PATH/z3-cflags.txt"
status=0
find "$ROOT/Sources" -name '*.swift' -print0 | xargs -0 swiftlint analyze \
  --strict \
  --config "$ROOT/.swiftlint.yml" \
  --compile-commands "$BUILD_PATH/compile_commands.json" \
  >"$BUILD_PATH/analyzer.log" 2>&1 || status=$?
cat "$BUILD_PATH/analyzer.log"
[ "$status" -eq 0 ] || exit "$status"
if ! grep -Eq 'Done analyzing! Found [0-9]+ violations, [0-9]+ serious in [1-9][0-9]* files?\.' "$BUILD_PATH/analyzer.log"; then
  echo "SwiftLint analyzer did not report nonzero source coverage." >&2
  exit 1
fi
awk -v platform="$(uname -s)" '
  function inactive_glibc(diagnostic, parts, file, number, line, previous, count) {
    split(diagnostic, parts, ":")
    file = parts[1]
    number = parts[2] + 0
    if (number < 2) { return 0 }
    count = 0
    while ((getline line < file) > 0) {
      count++
      if (count == number) {
        close(file)
        return line ~ /^[[:space:]]*import Glibc[[:space:]]*$/ && \
          previous ~ /^[[:space:]]*#elseif canImport\(Glibc\)[[:space:]]*$/
      }
      previous = line
    }
    close(file)
    return 0
  }
  /(^|: )error:/ {
    if (platform == "Darwin" && /: error: no such module '\''Glibc'\''$/ && inactive_glibc($0)) {
      known = 1
    } else {
      unexpected = 1
    }
  }
  END {
    if (known) {
      print "SourceKit reported the accepted inactive Glibc branch limitation." > "/dev/stderr"
    }
    if (unexpected) { exit 1 }
  }
' "$BUILD_PATH/analyzer.log"
