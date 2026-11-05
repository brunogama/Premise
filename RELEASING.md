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
- Publish only through the approved main-branch automation or an explicit user request.
- Once a version has been released, its contents must not be modified.
- Any post-release change requires a new version.
- Release from validated `main`, not from a long-lived release branch.

---

## Automatic version tags

`.github/workflows/semantic-release.yml` waits for `CI` to pass for a push to
`main` in this repository. It publishes a version if the unreleased commits
include a feature, fix or breaking change. Pull request runs, failed CI, manual
runs and fork runs cannot publish.

The command analyzes commits since the highest reachable stable
`vMAJOR.MINOR.PATCH` tag. It ignores merge commit messages but includes commits
from merged branches. For squash merges, use a Conventional Commit message for
the squash commit. A breaking change takes precedence over a feature, and a
feature takes precedence over a fix. Types are case-insensitive, so `Feat:` and
`FIX:` behave like `feat:` and `fix:`. Breaking footer tokens must be uppercase.

| Commit message | Result from `v1.0.2` |
| --- | --- |
| `fix: repair replay` | `v1.0.3` |
| `feat(replay): add trace support` | `v1.1.0` |
| `refactor!: rename replay` | `v2.0.0` |
| Any conventional type with a `BREAKING CHANGE:` or `BREAKING-CHANGE:` footer | `v2.0.0` |
| Only `docs:`, `chore:`, other nonbreaking types, or nonconventional commits | No tag |

The command uses only stable tags without leading zeros as baselines. It ignores
prerelease tags and tags outside the current commit's ancestry. If it finds no
stable baseline, it exits with an error.

CI must pass all jobs, including the release-command tests. A macOS job with
read-only permissions then runs strict Swift format and SwiftLint checks with
the root configurations. It also runs the analyzer after a fresh build and runs
repository QA. The publisher runs only if that job succeeds. Only one release
runs at a time. A new run does not cancel a publication already in progress.

The publisher requires a clean worktree and index. It compares the checked-out
CI commit with the current tip of `main` on `origin`. If they differ, it exits
successfully without publishing. It checks the README versions between the
release markers before editing them. Each version must match the baseline tag.
It commits only `README.md` and creates an annotated tag on that commit. It pushes
`main` and the tag together with `git push --atomic`, without force. It refuses
to replace an existing tag.

Before Git sends the updates, `scripts/release_push.py` checks the old SHA that
`origin` advertised for `main`. It must match the CI commit. If another writer
rewinds `main` before Git negotiates the push, the hook rejects publication.
The server also compares its current `main` SHA with that old SHA before
accepting the push. It accepts both updates or neither.

The publisher honors `core.hooksPath`, including relative paths. It restores the
original Git configuration environment before running existing hooks. It
preserves their arguments, standard input, working directory and exit behavior.
Other configured hooks still run when Git calls them during the push. Only this
push uses the temporary hook configuration. The publisher does not write
repository or user settings. A rerun after success does not create another version.

The command edits only the installation text between
`<!-- release-version:start -->` and `<!-- release-version:end -->`.
Keep the five installation versions, tag label and tag URL consistent with the
baseline tag. The command leaves other README text and version numbers unchanged.

Only the publisher job has `contents: write` permission. Its commits use the
GitHub Actions bot identity. The repository must allow its `GITHUB_TOKEN` to push
`main` and create tags. The publisher does not bypass protection rules. If a rule
blocks a write, publication fails. Pushes that use `GITHUB_TOKEN` do not trigger
push-based workflows. The README commit and tag therefore do not start another
CI or release run.

### Inspect a release plan

Use Python 3.10 or newer and a checkout with full Git history. From the repository
root, run:

```bash
python3 -B scripts/release_version.py
```

The default mode reads local history and README content. It does not fetch,
edit files or change Git references. It prints JSON with `planned` or `skipped`,
the baseline, the proposed version and the tag. Fetch history and tags separately
if your checkout is incomplete. Only the CI publisher should use `--publish`.
The command does not run Swift validation.

If the SHA check or an existing pre-push hook rejects publication, the publisher
does not update remote references. If the server rejects an update, it rejects
both the branch and tag. A competing writer's change or rollback remains in place.
The CI checkout may still contain its local README commit and tag. Inspect the
error and current remote references before retrying from a fresh checkout of the
intended `main` commit. That commit must have passed CI. Do not undo a deliberate
rollback or bypass a rejecting hook to make a retry succeed.

Do not force-push or move a published tag. If you lose the push response, inspect
remote `main` and the tag before retrying. Use a fresh checkout for the retry.
Other authorized writers can still change branches or tags after this push.

### Keep macro publication separate

This automation creates only a README commit and a Git tag. It does not create a
GitHub Release, change `CHANGELOG.md`, publish macro assets, or update the pinned
macro URL and checksum in `Package.swift`. The existing
`.github/workflows/release.yml` handles macro artifacts separately. A Git tag does
not trigger its `release: created` event. Use the manual release checklist below
when preparing release notes or publishing macro artifacts. Maintainers own
changelog entries.

---

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

## Stable Release Policy
The `v1.0.0` tag is the first stable public API release.

- `PATCH`: backward-compatible bug fixes and small internal corrections
- `MINOR`: new backward-compatible features
- `MAJOR`: breaking API or behavior changes after `v1.0.0`

SwiftPM version requirements use `1.0.0` while the Git tag uses `v1.0.0`.

## When to Bump
### Patch
Use for:
- bug fixes
- internal fixes with no API change
- build or packaging fixes without public API changes
- Use `fix:` for corrections that need a release. Docs-only commits do not create tags.

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

Create tags only through the approved main-branch automation or an explicit user request.

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
