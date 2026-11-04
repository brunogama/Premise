#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/premise-analyzer-commands.XXXXXX")"
trap 'rm -rf "$work"' EXIT
work="$(cd "$work" && pwd -P)"
mkdir -p "$work/debug/Modules"
printf '%s\n' '-DZ3_ANALYZER_PROBE' > "$work/cflags.txt"
python3 - "$work" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
commands = {}
for name in ("PremiseSQLite", "PremiseSMT", "PremiseCore"):
    source = root / "Sources" / name / "Probe.swift"
    source.parent.mkdir(parents=True)
    source.touch()
    commands[name] = {
        "otherArguments": [],
        "sources": [str(source)],
        "importPath": str(root / "debug" / "Modules"),
        "moduleName": name,
    }
(root / "debug" / "description.json").write_text(json.dumps({"swiftCommands": commands}))
PY
swift "$root/scripts/write_swiftlint_compile_commands.swift" \
  "$work" "$work/debug" "$work/commands.json" "$work/cflags.txt"
python3 - "$work" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
records = json.loads((root / "commands.json").read_text())
assert len(records) == 3
for record in records:
    arguments = record["arguments"]
    name = Path(record["file"]).parent.name
    flags = [str(Path(arg.split("=", 1)[1]).resolve()) for arg in arguments
             if arg.startswith("-fmodule-map-file=")]
    expected = {"PremiseSQLite": "CSQLite", "PremiseSMT": "CZ3"}.get(name)
    maps = [] if expected is None else [str(root / "Sources" / expected / "module.modulemap")]
    assert flags == maps, (name, flags, maps)
    assert ("-DZ3_ANALYZER_PROBE" in arguments) == (name == "PremiseSMT")
PY
printf 'Analyzer compiler-command regression passed.\n'
