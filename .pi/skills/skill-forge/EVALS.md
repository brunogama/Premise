# Detection cases

Use each case as a fresh-context prompt with `SKILL.md` and the applicable repository resources. Record the decision and cited evidence; a case passes only when both match the expected result.

1. **New candidate**: A completed, verified deployment uses a repeatable sequence of at least three meaningful command steps with a distinct trigger and no existing skill coverage. Expect a new candidate and the approval-gated pipeline.
2. **Existing skill**: The same deployment is fully covered by an active skill. Expect use of the existing skill and no candidate.
3. **Revision**: An active deployment skill covers the trigger but lacks a verified recovery step. Expect a staged revision of that skill, not a parallel skill.
4. **SOP**: A proposal defines an approval rule shared by several tools. Expect an SOP, not a skill candidate.
5. **Memory**: A user states a durable preference without a reproducible procedure. Expect memory, not a skill candidate.
6. **Insufficient evidence**: A command sequence was attempted but its outcome was not verified. Expect insufficient evidence and no candidate.
7. **Transient work**: A one-time status update has no reusable procedure. Expect no candidate.

## Recorded evaluation

A fresh-context evaluator classified all seven cases on 2026-10-29 without reading the expected outcomes. `actual.txt` records the classifications normalized from its report; `expected.txt` records the expected classifications. Case 1 assumes a distinct ownership boundary. Case 3 assumes the verified recovery step is repeatable and belongs to the existing skill's scope.

Run the deterministic comparison from this directory:

```sh
diff -u expected.txt actual.txt
```

An exit status of zero means the recorded labels match. This checks the transcription, not the evaluator's reasoning or whether another run will produce the same decisions. For a new evaluation, collect fresh independent classifications before updating `actual.txt`.
