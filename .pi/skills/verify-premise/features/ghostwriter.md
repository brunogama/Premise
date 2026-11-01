# Generate a property skeleton

The SwiftPM command plugin produces a starting point for a property or fuzz test.

---
## Sub-features

- `ghostwriter-fuzz`: generate a fuzz-no-crash skeleton on stdout.

---
## How to get to it (user POV)

- Run `swift package premise-ghostwriter` in the Premise checkout.

---
## Driving it with SwiftPM

Preconditions: complete Launch and Doctor. Run from the checkout and retain stdout, stderr, and exit code:

```bash
cd "$PREMISE_ROOT" || exit 1
swift package --disable-automatic-resolution premise-ghostwriter \
  --kind fuzz --module MyApp --type Payload \
  --strategy 'Strategy<Payload>.payloads()' --subject 'parse($0)' \
  > "$EVIDENCE/ghostwriter.swift" 2> "$EVIDENCE/ghostwriter.stderr"
rc=$?
printf 'exit_code=%s\n' "$rc" > "$EVIDENCE/ghostwriter.exit"
test "$rc" -eq 0
```

Inspect stdout for `payloadFuzzNoCrash`, `fuzzOneInput`, and the requested strategy. The sample names are inputs to the generator, not a real module; generated code is not proven to compile by this check.

---
## Gotchas

- The plugin may build its tool in the checkout's `.build`; do not delete that shared build directory in cleanup.
- Other template kinds and generated-code compilation are separate, unverified journeys.
