#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/premise-staged-lint-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q
mkdir -p Sources Tests/MacroRegression
cat > .swiftlint.yml <<'YAML'
only_rules:
  - line_length
line_length:
  warning: 20
  error: 20
YAML
cat > Tests/MacroRegression/.swiftlint.yml <<'YAML'
parent_config: ../../.swiftlint.yml
line_length:
  warning: 100
  error: 100
YAML
cat > 'Tests/MacroRegression/file with space.swift' <<'SWIFT'
let text = "This line is longer than twenty characters."
SWIFT
git add .swiftlint.yml Tests/MacroRegression/.swiftlint.yml \
  'Tests/MacroRegression/file with space.swift'
cat > Tests/MacroRegression/.swiftlint.yml <<'YAML'
parent_config: ../../.swiftlint.yml
line_length:
  warning: 10
  error: 10
YAML
if ! sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  cat "$work/output" >&2
  echo 'Expected staged nested config, not the root or worktree config.' >&2
  exit 1
fi
cat > 'Tests/MacroRegression/file with space.swift' <<'SWIFT'
let text = "This deliberately long line must exceed the staged nested limit, even when the working copy is short and clean."
SWIFT
git add 'Tests/MacroRegression/file with space.swift'
printf 'let text = "ok"\n' > 'Tests/MacroRegression/file with space.swift'
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a staged violation despite a clean worktree file.' >&2
  exit 1
fi
if ! grep -F 'Tests/MacroRegression/file with space.swift:' "$work/output" >/dev/null; then
  cat "$work/output" >&2
  echo 'Expected the original path in diagnostics.' >&2
  exit 1
fi
printf 'let text = "ok"\n' > 'Tests/MacroRegression/file with space.swift'
git add 'Tests/MacroRegression/file with space.swift'
cat > Tests/MacroRegression/.swiftlint.yml <<'YAML'
parent_config: ../../missing.yml
YAML
git add Tests/MacroRegression/.swiftlint.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a missing staged parent config to fail closed.' >&2
  exit 1
fi
if ! grep -F 'missing.yml' "$work/output" >/dev/null; then
  cat "$work/output" >&2
  echo 'Expected a diagnostic identifying the missing parent config.' >&2
  exit 1
fi
cat > Tests/MacroRegression/.swiftlint.yml <<'YAML'
parent_config: ../../.swiftlint.yml
YAML
git add Tests/MacroRegression/.swiftlint.yml
printf 'let text = "This exceeds the inherited root limit."\n' > 'Tests/MacroRegression/file with space.swift'
git add 'Tests/MacroRegression/file with space.swift'
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected the nested config to inherit the staged root policy.' >&2
  exit 1
fi
if ! grep -F 'Line Length Violation' "$work/output" >/dev/null; then
  cat "$work/output" >&2
  echo 'Expected an inherited line length violation.' >&2
  exit 1
fi

cat > 'Tests/parent policy.yml' <<'YAML'
parent_config: ../.swiftlint.yml
line_length:
  warning: 100
  error: 100
YAML
printf 'parent_config: "../parent policy.yml"\n' > Tests/MacroRegression/.swiftlint.yml
git add 'Tests/parent policy.yml' Tests/MacroRegression/.swiftlint.yml
printf 'invalid: [\n' > 'Tests/parent policy.yml'
if ! sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  cat "$work/output" >&2
  echo 'Expected the staged custom parent config, not its worktree version.' >&2
  exit 1
fi
printf 'let x = 1\n' > 'Tests/MacroRegression/file with space.swift'
git add 'Tests/MacroRegression/file with space.swift'
printf 'parent_config: ../../../outside.yml\n' > Tests/MacroRegression/.swiftlint.yml
git add Tests/MacroRegression/.swiftlint.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a parent config outside the repository to fail closed.' >&2
  exit 1
fi
grep -F 'Invalid parent_config traversal' "$work/output" >/dev/null

printf 'parent_config: [\n' > Tests/MacroRegression/.swiftlint.yml
git add Tests/MacroRegression/.swiftlint.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected malformed staged config to fail closed.' >&2
  exit 1
fi
grep -F 'Invalid staged config' "$work/output" >/dev/null

printf 'parent_config: cycle.yml\n' > Tests/MacroRegression/.swiftlint.yml
printf 'parent_config: .swiftlint.yml\n' > Tests/MacroRegression/cycle.yml
git add Tests/MacroRegression/.swiftlint.yml Tests/MacroRegression/cycle.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a staged config inheritance cycle to fail closed.' >&2
  exit 1
fi
grep -F 'Config inheritance cycle' "$work/output" >/dev/null

printf 'child_config: nested.yml\n' > Tests/MacroRegression/.swiftlint.yml
git add Tests/MacroRegression/.swiftlint.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected an unsupported child config to fail closed.' >&2
  exit 1
fi
grep -F 'Unsupported child_config' "$work/output" >/dev/null
blob=$(printf 'parent_config: ../../.swiftlint.yml\n' | git hash-object -w --stdin)
git update-index --force-remove Tests/MacroRegression/.swiftlint.yml
printf '100644 %s 1\tTests/MacroRegression/.swiftlint.yml\n100644 %s 2\tTests/MacroRegression/.swiftlint.yml\n' "$blob" "$blob" | git update-index --index-info
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a conflicted staged config to fail closed.' >&2
  exit 1
fi
grep -F 'Cannot use conflicted config' "$work/output" >/dev/null

git update-index --force-remove Tests/MacroRegression/.swiftlint.yml
git update-index --force-remove .swiftlint.yml
if sh "$root/scripts/lint_staged_swift.sh" \
  'Tests/MacroRegression/file with space.swift' >"$work/output" 2>&1; then
  echo 'Expected a missing staged root config to fail closed.' >&2
  exit 1
fi
grep -F 'Staged root .swiftlint.yml is required' "$work/output" >/dev/null
printf '%s\n' 'Staged SwiftLint configuration test passed.'
