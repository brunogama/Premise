# SOP and skill conventions

## Architecture authority

1. Read `README.md` for the current project domain and public behavior. `concepts_brief.md` records design discussion and decisions; check its stated status before treating any item as authoritative.
2. Consult applicable accepted design and security decisions when available; do not assume an unrecorded design or ADR exists.
3. Never silently weaken an accepted authority, enforcement, lifecycle, portability, or fail-closed decision.
4. When a later decision changes an accepted ADR, add explicit status or supersession metadata instead of rewriting its prior meaning.
5. Report missing assurance evidence as `INCOMPLETE`, never `PASS`.

---

## Create a skill when

- The work involves repeatable tool calls, commands, or API interactions.
- An agent can follow the instructions to reproduce a technical outcome.
- The skill has a clear activation trigger and ownership boundary.

---

## Create an SOP when

- The content is a governance or process rule.
- The rule applies across several tools or skills.

---

## Skill lifecycle

1. Collect evidence from a completed task.
2. Induce a candidate under `_candidates/`.
3. Deductively verify it from a fresh context.
4. Check overlap with active skills.
5. Request explicit human approval.
6. Promote and log only after approval.
