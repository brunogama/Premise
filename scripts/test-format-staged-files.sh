#!/bin/sh
set -eu
root=$(git rev-parse --show-toplevel)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/premise-staged-format.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/scripts"
cp "$root/.swift-format" "$tmp/.swift-format"
cp "$root/scripts/format_staged_files.sh" "$tmp/scripts/format_staged_files.sh"
cd "$tmp"
git init -q
printf 'let values = [\n  1,\n  2,\n]\n' > scripts/example.swift
git add scripts/example.swift
swift format format --configuration .swift-format scripts/example.swift > expected.swift
printf '// unstaged change\n' >> scripts/example.swift
sh scripts/format_staged_files.sh scripts/example.swift
git show :scripts/example.swift > actual.swift
cmp expected.swift actual.swift
grep -q '^// unstaged change$' scripts/example.swift
printf 'Staged formatter uses the root policy and preserves unstaged changes.\n'
