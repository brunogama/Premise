---
name: skill-forge
description: Detect when completed work, repeated corrections, or a resolved bug warrants a skill candidate; stage and verify it through the approval-gated lifecycle.
tags: [meta, self-improvement, skills, sop]
date: 2026-07-29
---

# Skill Forge

Convert real task evidence into a verified skill candidate without changing active skills before approval.

## Trigger

- A task with three or more non-trivial steps completed.
- The same user correction appeared twice.
- A non-trivial bug was reproduced and resolved.
- The user asks whether work warrants a candidate or invokes `forge-skill` for a topic.

## Detection gate

Evaluate the completed task when a trigger fires. Record the evidence and make exactly one decision:

1. **Collect** - Identify the completed outcome, reusable trigger, concrete steps, and verification evidence. Cite the task or correction without copying sensitive content.
2. **Classify** - Continue only when the procedure uses repeatable tool calls, commands, or API interactions, has a clear scope, and can reproduce a technical outcome. Route cross-tool governance to an SOP, and isolated facts or preferences to memory. Report insufficient evidence for an unfinished or unverified procedure.
3. **Compare** - Inspect relevant active skill descriptions and bodies. Use an existing skill when it already covers the procedure; stage a revision when it needs new behavior. Create a new candidate only when its trigger and ownership are distinct.
4. **Decide** - Report the evidence, decision, and destination: existing skill, candidate revision, new candidate, SOP, memory, or no candidate. For a new or revised candidate, proceed through the pipeline below; otherwise stop without creating a skill.

## Harness paths

Choose the current harness root once:

| Harness | Active skill root | Candidate root |
| --- | --- | --- |
| Claude | `.claude/skills/` | `.claude/skills/_candidates/` |
| Pi | `.pi/skills/` | `.pi/skills/_candidates/` |
| Codex/shared | `.agents/skills/` | `.agents/skills/_candidates/` |

Call these `<active-skill-root>` and `<candidate-root>` below. Never substitute a different harness's root.

## Pipeline

### 1. Collect

Read the session evidence, diff, task summary, and [llms/learnings/CORRECTIONS.md](../../../llms/learnings/CORRECTIONS.md) when available. Record missing evidence and identify the steps, failures, correction, and observable outcome.

### 2. Induce

Use `docs/templates/skill-template.md` to write an imperative, parameterized procedure. Stage it at `<candidate-root>/<kebab-name>/SKILL.md`.

For a revision to an active skill, copy that skill into `<candidate-root>/<existing-name>/` and edit the candidate copy. Never edit the active copy before approval.

### 3. Deduct

When delegation is authorized, give only the candidate and its explicit resources to a fresh agent. Ask it to reconstruct the outcome. Otherwise report deduction as INCOMPLETE and request authorization.

- Pass: record evidence and proceed.
- Fail: add the missing instruction and retry, up to two rounds.

### 4. De-duplicate

Compare candidate descriptions against `<active-skill-root>*/SKILL.md`.

- Strong overlap: revise the existing skill through a candidate copy.
- Partial overlap: keep distinct ownership boundaries; declare `supersedes` only when the new skill replaces the existing one.
- No overlap: keep the new candidate name.

### 5. Request approval

Present the trigger, a five-line procedure summary, deduction evidence, and whether the change is new, revised, or superseding. Wait for explicit human approval.

### 6. Promote

Only after approval:

1. For a new skill, move the candidate into `<active-skill-root><name>/`. For a revision, replace the approved active files with their candidate counterparts after checking for changes since staging; preserve unrelated files and stop if ownership is unclear.
2. Append the approved promotion to [llms/learnings/SKILLS-LOG.md](../../../llms/learnings/SKILLS-LOG.md).

## Rejection criteria

- No generalizable trigger.
- The candidate duplicates an active skill without revising it.
- Deduction still fails after two rounds.
- A new candidate has fewer than three meaningful procedure steps. A revision may add fewer steps to an existing procedure.
- The procedure is unverified, has no distinct ownership boundary, or captures only a fact or temporary task state.

## Files

- Reads: session evidence, corrections, active skill descriptions, and the skills log.
- Writes before approval: `<candidate-root>` only.
- Writes after approval: `<active-skill-root>` and [llms/learnings/SKILLS-LOG.md](../../../llms/learnings/SKILLS-LOG.md).
