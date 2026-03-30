# RELEASING.md

## Purpose
Repository release and changelog rules.

This file defines how to prepare, version, and publish releases.
For code quality gates, follow `RULES.md`.
For day-to-day repository operating behavior, follow `AGENTS.md`.

## Release Principles
- Every release must correspond to intentional, validated code.
- Do not release from a dirty worktree.
- Do not release if formatter, lint, build, tests, or coverage gates fail.
- Do not publish a release unless the user explicitly asked.
- Once a version has been released, its contents must not be modified.
- Any post-release change requires a new version.
- Release from validated `main`, not from a long-lived release branch.

## Versioning
Use semantic versioning:
- `MAJOR`: breaking changes
- `MINOR`: backward-compatible features
- `PATCH`: backward-compatible fixes

Examples:
- `1.0.0` — first stable release
- `1.1.0` — new feature, no breaking change
- `1.1.1` — bug fix only
- `2.0.0` — breaking API or behavior change

## Pre-1.0 Policy
This repository is currently in the `0.y.z` phase.

- `PATCH`: backward-compatible bug fixes and small internal corrections
- `MINOR`: new backward-compatible features and any breaking change introduced before `1.0.0`
- `1.0.0`: reserved for the first release with a stable public API

Until `1.0.0`, the public API is not considered stable.

## When to Bump
### Patch
Use for:
- bug fixes
- internal fixes with no API change
- build or packaging fixes without public API changes
- docs-only clarifications if this repository tags docs releases

### Minor
Use for:
- new backward-compatible features
- new modules, commands, options, or extension points
- meaningful DX improvements that do not break callers
- breaking changes while the repository remains in `0.y.z`

### Major
Use for:
- removed or renamed public APIs
- changed public behavior requiring migration
- changed defaults with significant user impact
- incompatibilities in package structure, configuration, or supported platforms

## Changelog Policy
Maintain a human-readable changelog.
Use `YYYY-MM-DD` release dates.

Recommended section structure:
- Added
- Changed
- Fixed
- Deprecated
- Removed
- Security

Rules:
- Write for users, not for Git history.
- Do not dump raw commit messages.
- Do not include trivial internal churn unless users are affected.
- Group related changes into clear bullets.
- Call out breaking changes explicitly.
- Call out migration steps when needed.

## Changelog Entry Style
Good:
- Added typed extractor support for multi-binding variable declarations.
- Fixed nil-coalescing rendering in release builds.
- Changed local validation to fail on warnings.

Bad:
- update files
- fix stuff
- refactor code
- cleanup

## Release Checklist
Before releasing:
1. Confirm intended release scope.
2. Ensure the worktree is clean.
3. Run full validation required by `RULES.md`.
4. Confirm public API and behavior changes are documented.
5. Update version numbers in all required locations.
6. Update `CHANGELOG.md`.
7. Verify installation and quick-start examples still work.
8. Verify packaging, manifests, and release artifacts are correct.
9. Commit release changes if the user explicitly asked for a commit.
10. Tag the release if the user explicitly asked.

## Multi-Package Repositories
If this repository contains multiple publishable units:
- decide whether versioning is lockstep or independent
- do not mix both strategies accidentally
- if lockstep, all published packages share the same version
- if independent, update only impacted packages and their dependency constraints

Recommended rule:
- use lockstep only if packages are tightly coupled and released together
- use independent versioning only if packages are truly separable operationally and semantically

## Tagging
Recommended tag format:
- `v1.2.3`

Examples:
- `v0.4.0`
- `v1.0.0`
- `v2.3.1`

Do not create tags unless the user explicitly asked.

## Release Notes
Release notes should summarize:
- what changed
- why it matters
- whether there are breaking changes
- what users need to do next

Recommended structure:
- Summary
- Highlights
- Breaking changes
- Migration notes
- Upgrade instructions

## Breaking Changes
If a release is breaking:
- bump the correct version line according to the current phase
- state the break clearly
- explain impacted users
- provide migration guidance
- avoid vague wording like `some APIs changed`

Bad:
- Several internals were improved.

Good:
- Renamed `VectorIndex.build()` to `VectorIndex.create()` and changed the initializer to require an explicit metric.

## Rollback Readiness
Before publishing, verify:
- the previous version can still be identified and restored
- release artifacts are reproducible
- any generated files are committed if the repository requires them
- version bumps are internally consistent

## Release Command Policy
If the repository uses release scripts:
- prefer scripted release steps over ad hoc manual edits
- do not bypass validation inside release scripts
- keep release scripts idempotent where possible
- keep version bump logic centralized

## Post-Release Checks
After a release, verify:
- the tag matches the intended version
- published artifacts match the tagged source
- package metadata is correct
- install instructions still resolve
- changelog and release notes are visible and accurate
