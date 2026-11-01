# Inspect a replay trace

A user inspects a saved failure artifact or reproduction blob to obtain a trace for replaying a failing property.

---
## Sub-features

- `replay-file`: inspect an existing failure artifact file.
- `replay-blob`: inspect an existing reproduction blob.

---
## How to get to it (user POV)

- Run `swift package premise-replay` with a trace file or `--blob` followed by a reproduction blob.

---
## Driving it with SwiftPM

Preconditions: complete Launch and Doctor. Obtain a real failure artifact or blob from the property run under investigation and record its provenance. If neither is available, report this journey blocked; do not substitute a help command.

```bash
cd "$PREMISE_ROOT" || exit 1
swift package --disable-automatic-resolution premise-replay "$TRACE_FILE" \
  > "$EVIDENCE/replay.txt" 2> "$EVIDENCE/replay.stderr"
rc=$?
printf 'exit_code=%s\n' "$rc" > "$EVIDENCE/replay.exit"
test "$rc" -eq 0
```

For a failure artifact, inspect the expected property identity when present. For either input, check the trace entry and span counts, reproduction blob, and decoding snippet. The command does not execute the property; replaying it requires using the decoded trace with the runner. For the blob entry point, substitute `--blob "$TRACE_BLOB"` for `"$TRACE_FILE"`, retain separate output, and verify it independently.

---
## Gotchas

- No trace is seeded by Launch. This journey remains unverified until a real failure is supplied.
- Trace contents may contain application data; check before sharing evidence.
