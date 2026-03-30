# Contributing to Conjecture

Thank you for contributing to Conjecture.
This repository uses trunk-based development with `main` as the default trunk.

## Current Repository Stage

The repository has completed its Phase 1 package bootstrap.
Top-level policy files, `Package.swift`, the first module targets, and smoke
tests are now in place.

Until the deterministic engine lands:

- keep changes small and focused
- prefer trunk-safe slices that preserve the Phase 1 architecture contract
- do not let runtime implementation work leak `Testing` or XCTest into
  `ConjectureCore` or `ConjectureStrategies`
- update contributor docs when repository capabilities change

## Core Expectations

- Keep changes small and trunk-safe.
- Prefer one logical change per branch or commit.
- Avoid unrelated cleanup while the package layout is still forming.
- Update user-facing docs when project behavior or setup changes.
- Follow `AGENTS.md`, `RULES.md`, and `WORKFLOW.md` before opening a PR.

## Reporting Issues

1. Search existing issues first.
2. Provide clear reproduction steps or the missing behavior you expected.
3. Include toolchain details such as Swift version, OS, and Xcode version.
4. Link any architecture or planning documents that shaped the request.

## Development Setup

### Prerequisites

- Swift 6 toolchain
- Xcode 16 or newer for Apple-platform development
- macOS 13 or newer

### Current State

The package scaffold exists and should be treated as the source of truth for the
current module graph. If your branch changes the package layout or validation
commands, update this guide in the same change so setup instructions stay true.

## Local Validation

For documentation and config-only changes, run the checks that apply to the
files you touched.

For Swift changes, follow the repository gates from `RULES.md`:

```bash
swift-format -i --configuration .swift-format <changed-swift-files>
swiftlint lint --fix --config .swiftlint.yml <changed-swift-files>
swiftlint lint --strict --config .swiftlint.yml <changed-swift-files>
bash scripts/validate-boundaries.sh
swift build --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
swift test --explicit-target-dependency-import-check error -Xswiftc -warnings-as-errors
```

If the repository later adds wrapper scripts or CI entrypoints, prefer those
over raw commands and update this file accordingly.

## Coding Standards

- Follow Swift API Design Guidelines.
- Keep functions, files, and types within the budgets described in `RULES.md`.
- Add `///` documentation comments for public APIs.
- Prefer value-oriented, strict-concurrency-safe designs in the hot path.
- Keep v2 capabilities as additive seams rather than default package dependencies.
- Update `README.md` when package layout, installation, or public behavior changes.

## Commit Messages

This repository uses Conventional Commits as documented in `.gitmessage`.

Format:

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

Rules:

- use lowercase commit types
- keep the subject concise and under 100 characters
- keep each commit scoped to one logical change
- include issue or ticket footers when repository policy or the task requires them

## Pull Requests

1. Sync with `main`.
2. Keep the change focused on one logical slice.
3. Run the relevant local validation for the files you changed.
4. Update docs when the repo setup or public API changes.
5. Open a small PR against `main`.

### PR Checklist

- [ ] the diff is one logical slice
- [ ] relevant validation passed locally
- [ ] docs and repo metadata stay accurate
- [ ] placeholder or copied project names were not introduced
- [ ] incomplete work is either hidden or deferred

## Release Process

Releases are managed by maintainers and documented in `RELEASING.md`.
Do not cut releases until the package scaffold, validation gates, and changelog
policy are all in place.

## Getting Help

- Questions: open a GitHub Discussion or issue
- Bugs: open a GitHub Issue with reproduction details
- Security: use the process documented in `SECURITY.md`

## License

By contributing, you agree that your contributions will be licensed under the
MIT License.
