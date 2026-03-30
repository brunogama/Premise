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

## When to Bump
### Patch
Use for:
- bug fixes
- internal fixes with no API change
- build or packaging fixes without public API changes
- docs-only clarifications if your repo tags docs releases

### Minor
Use for:
- new backward-compatible features
- new modules, commands, options, or extension points
- meaningful DX improvements that do not break callers

### Major
Use for:
- removed or renamed public APIs
- changed public behavior requiring migration
- changed defaults with significant user impact
- incompatibilities in package structure, configuration, or supported platforms

## Changelog Policy
Maintain a human-readable changelog.

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
- Added HNSW index build command for offline vector indexing.
- Fixed null handling in distance function for sparse records.
- Changed default package validation to fail on warnings.

Bad:
- update files
- fix stuff
- refactor code
- cleanup

## Release Checklist
Before releasing:

1. Confirm intended release scope.
2. Ensure worktree is clean.
3. Run full validation required by `RULES.md`.
4. Confirm public API and behavior changes are documented.
5. Update version numbers in all required locations.
6. Update `CHANGELOG.md`.
7. Verify installation and quick-start examples still work.
8. Verify packaging, manifests, and release artifacts are correct.
9. Commit release changes if the user explicitly asked for a commit.
10. Tag the release if the user explicitly asked.

## Multi-Package Repositories
If this repository contains multiple packages or publishable units:

- Decide whether versioning is lockstep or independent.
- Do not mix both strategies accidentally.
- If lockstep, all published packages share the same version.
- If independent, update only impacted packages and their dependency constraints.

Recommended rule:
- Use lockstep only if packages are tightly coupled and released together.
- Use independent versioning only if packages are truly separable operationally and semantically.

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

- bump major version
- state the break clearly
- explain impacted users
- provide migration guidance
- avoid vague wording like “some APIs changed”

Bad:
- Several internals were improved.

Good:
- Renamed `VectorIndex.build()` to `VectorIndex.create()` and changed the initializer to require an explicit metric.

## Rollback Readiness
Before publishing, verify:
- the previous version can still be identified and restored
- release artifacts are reproducible
- any generated files are committed if the repo requires them
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

## TOOLS

- Use ast-swift-search when needs to research files, its faster then normal searches commands and you can have detailed information of file.

# ExecPlans

When writing complex features or significant refactors, use an ExecPlan (as described in .agent/PLANS.md) from design to implementation.w
