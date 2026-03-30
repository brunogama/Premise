# AI Coding Agent Rules (Project-Agnostic, Lint-First)

## Purpose
Ensure any AI agent changes compile cleanly, pass tests, and comply with repository lint and format rules by design, not by cleanup at the end.

## 1) Non-negotiables (Definition of Done)
Work is not done unless all items below are true:

1. Formatting is applied using the repository formatter.
2. Lint is clean: run lint fix mode if available, then strict mode, on the changed files.
3. Zero warnings and zero errors when building with warnings treated as errors.
4. Tests pass.
5. Coverage gate passes when the repository enforces it.
6. No bypasses: never use `--no-verify`, never disable hooks, never temporarily commit broken code.

If your output would fail repository hooks or CI, refactor before finishing.

## 2) Treat lint rules as design constraints
### 2.1 Hard budgets (SwiftLint defaults if the repo does not define tighter values)
- Line length: 100
- Function parameters: warn 4, error 6
- Function body length: warn 60, error 120
- Type body length: warn 300, error 800
- File length: warn 400, error 1000
- Cyclomatic complexity: warn 10, error 15
- Nesting: type level 2, function level 3

Also respect repository custom rules, such as preferring `struct` over `class` when appropriate and avoiding `print(...)` in production sources.

### 2.2 Refactor triggers
Refactor before adding more code when any of these are true:
- a function is likely to exceed ~50 lines
- complexity is increasing due to branching or deep nesting
- a file is trending past ~350 lines
- a type is becoming a god object with multiple responsibilities

## 3) Mandatory tactics to stay under budgets
### 3.1 Keep functions small and flat
- Prefer early exits over deep nesting.
- Extract helpers when a block exceeds roughly 10–15 lines, when a branch does more than one thing, or when a loop mixes responsibilities.
- Split do-everything functions into parse/validate, transform, perform, and persist phases when appropriate.

### 3.2 Reduce cyclomatic complexity
- Replace long if/else chains with table-driven mappings, small strategy types, or extracted switch handlers.
- If a switch has many cases, extract per-case helpers so the main function stays small.

### 3.3 Keep files and types small
- Prefer one main type per file.
- Split protocols, adapters, and mappers into separate files when they are not tiny helpers.
- Move large helper sections into `TypeName+Helpers.swift`, nested types, or separate collaborators.

### 3.4 Control parameter count
If a function wants more than four parameters, prefer a parameter object or a small domain type.

## 4) Process the agent must follow
1. Plan what will change and where.
2. Implement with budget-first refactoring.
3. Self-review for large functions, large files, nesting, complexity, and unnecessary public API.
4. Run the same checks the repository runs.

Typical Swift sequence:
- `swift-format -i --configuration .swift-format <changed files>`
- `swiftlint lint --fix --config .swiftlint.yml <changed files>`
- `swiftlint lint --strict --config .swiftlint.yml <changed files>`
- `swift test`
- `swift build -Xswiftc -warnings-as-errors`
- coverage script, if present

If any check fails, fix the code. Do not weaken rules.

## 5) Allowed exceptions
Temporary `swiftlint:disable` is allowed only when:
- you include a one-line justification
- you scope it to the smallest region
- you add a TODO with a removal plan

Never disable file length, function length, complexity, nesting, warnings-as-errors, or tests unless the repository owner explicitly changed policy.

## 6) Output requirements for AI agents
- Avoid unrelated refactors, reformat-only diffs, or renames unless required.
- Keep the public API stable unless the request explicitly requires changes.
- Prefer incremental, PR-friendly changes: small commits, small diffs, high signal.

## 7) Reusability
This file is intentionally project-agnostic.
Repository-specific details belong in `.swiftlint.yml`, `.swift-format`, CI, `Makefile`, and per-module READMEs.
When this document conflicts with repository tooling, tooling wins.
