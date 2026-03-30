# WORKFLOW.md

## Purpose
Repository workflow rules for coding agents and contributors.

This repository uses trunk-based development.
The trunk is `main` unless the repository explicitly defines another branch.
For code quality and validation rules, follow `RULES.md`.
For repository operating behavior during implementation, follow `AGENTS.md`.

## General Workflow
- Read the full task before acting.
- Prefer understanding the existing code path before proposing structural changes.
- Keep work scoped to the requested task.
- Do not mix implementation, cleanup, and unrelated refactors in the same change unless explicitly requested.
- Prefer the smallest releasable slice.
- Preserve the Phase 1 package contract: `ConjectureCore` and `ConjectureStrategies`
  stay free of `Testing` and XCTest imports.

## Issues
- Read the full issue, including comments, before changing code.
- Treat issue comments as part of the requirement unless they clearly contradict the latest user instruction.
- If the issue is underspecified, inspect the relevant code and docs before deciding on the implementation shape.
- Do not close issues unless the user explicitly asked.

## Branching
- Prefer direct work on `main` when repository policy allows it.
- If a branch is needed, it must be short-lived and focused on one small logical slice.
- Do not create long-lived feature branches, `develop`, integration branches, or release branches.
- Branches should be merged back as soon as checks pass.

Recommended patterns:
- `feat/<area>-<topic>`
- `fix/<area>-<bug>`
- `refactor/<area>-<topic>`
- `docs/<area>-<topic>`
- `chore/<area>-<topic>`

## Pull Requests
- Do not open a pull request unless the user explicitly asked.
- Do not merge a pull request unless the user explicitly asked.
- Keep PRs small, single-purpose, and easy to review.
- Review the full PR description and discussion before commenting.
- Prefer precise review comments tied to correctness, safety, DX, performance, maintainability, or repo policy.
- Do not approve code that passes superficially but violates `RULES.md`.

## Feature Delivery
- Large changes must be split into trunk-safe slices.
- If a feature is incomplete but must land, hide it behind a feature flag or inactive path.
- Do not leave `main` in a state that depends on a future stabilization branch.
- Keep the default build limited to the five v1 products until a roadmap phase
  explicitly adds a new package target.

## Review Expectations
When reviewing a change, check at minimum:
- correctness
- edge cases
- regression risk
- API impact
- test coverage
- lint and formatter compliance
- complexity and file-size budget impact
- backward compatibility where relevant
- documentation updates where relevant
- whether the slice is small enough for trunk

## Local Change Policy
- Change only what is necessary for the requested task.
- Avoid renames, file moves, or broad reorganizations unless they are part of the task.
- Avoid introducing compatibility layers unless there is a clear migration need.
- Prefer deletion over dead abstractions, but do not remove intentional behavior without approval.

## Commit Policy
- Never commit unless the user explicitly asked.
- Keep commits focused and logically grouped.
- One logical change per commit.
- Stage files explicitly by path.
- Verify staged content with `git status` and `git diff --cached` before committing.
- If `scripts/change-budget.sh` exists, run it before proposing or creating a commit.
- Reference the issue in the commit message when applicable using `fixes #<number>` or `closes #<number>`.

## Merge Policy
- Prefer squash merge for noisy or iterative branches.
- Prefer regular merge only when preserving commit history is important.
- Rebase only when it improves clarity and does not risk other contributors' work.
- Never force push shared branches.

## Conflict Policy
- Resolve conflicts only in files you intentionally touched.
- If conflicts appear in unrelated files, stop and ask the user.
- Do not use destructive Git commands to simplify conflict resolution.

## Documentation Expectations
Update docs when the change affects:
- public API
- setup or installation
- repository workflow
- release process
- package layout
- developer commands
- behavior users depend on

## Validation Commands

For Swift package changes, run the architecture and compile gates that Phase 1
established:

```bash
bash scripts/validate-boundaries.sh
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
```

## Escalation Triggers
Stop and ask the user before proceeding when:
- the requested change implies a breaking API change
- the safest fix requires structural refactoring beyond the task scope
- the repository state suggests another agent is actively editing overlapping files
- the issue requirements and current code behavior materially conflict
- the requested change is too large for a single trunk-safe slice
