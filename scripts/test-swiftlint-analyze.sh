#!/bin/sh
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
mkdir -p "$TEMP/project/Sources/Example" "$TEMP/build/Modules" "$TEMP/bin"
touch "$TEMP/project/Sources/Example/File.swift"
ln -s "$TEMP/project" "$TEMP/link"
python3 - "$TEMP" <<'PY'
import json, os, sys
base = sys.argv[1]
source = os.path.realpath(os.path.join(base, 'project/Sources/Example/File.swift'))
command = {'otherArguments': [], 'sources': [source], 'importPath': os.path.join(base, 'build/Modules'), 'moduleName': 'PremiseSMT'}
with open(os.path.join(base, 'build/description.json'), 'w') as out:
    json.dump({'swiftCommands': {'example': command}}, out)
PY
printf '%s\n' '-I/path with spaces' '-DTEST=1' > "$TEMP/cflags"
swift "$ROOT/scripts/write_swiftlint_compile_commands.swift" \
  "$TEMP/link" "$TEMP/build" "$TEMP/commands.json" "$TEMP/cflags"
python3 - "$TEMP/commands.json" <<'PY'
import json, sys
with open(sys.argv[1]) as source:
    records = json.load(source)
assert len(records) == 1, f'expected one source record, got {len(records)}'
arguments = records[0]['arguments']
assert '-fmodule-map-file=' in ' '.join(arguments)
assert arguments[arguments.index('-I/path with spaces') - 1] == '-Xcc'
assert arguments[arguments.index('-DTEST=1') - 1] == '-Xcc'
PY
printf '%s\n' '{"swiftCommands":{}}' > "$TEMP/build/description.json"
if swift "$ROOT/scripts/write_swiftlint_compile_commands.swift" \
  "$TEMP/link" "$TEMP/build" "$TEMP/empty.json" "$TEMP/cflags" >"$TEMP/output" 2>&1; then
  echo 'Expected an empty compile database to fail' >&2
  exit 1
fi
grep -q 'No Swift source compile commands found' "$TEMP/output"
cat > "$TEMP/bin/pkg-config" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$TEMP/bin/pkg-config"
if PATH="$TEMP/bin:$PATH" "$ROOT/scripts/run_swiftlint_analyze.sh" "$ROOT" >"$TEMP/output" 2>&1; then
  echo 'Expected missing Z3 to fail' >&2
  exit 1
fi
if ! grep -q 'pkg-config.*z3' "$TEMP/output"; then
  echo 'Missing Z3 did not produce the expected diagnostic' >&2
  cat "$TEMP/output" >&2
  exit 1
fi
echo 'SwiftLint analyzer regression checks passed.'
