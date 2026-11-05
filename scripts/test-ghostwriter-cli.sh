#!/usr/bin/env bash
set -euo pipefail

stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT

if swift package premise-ghostwriter \
  --kind fuzz --module --type --type T --strategy S \
  >"$stderr_file" 2>&1; then
  echo 'Expected the command to reject a missing --module value' >&2
  exit 1
fi

if ! grep -Fq 'Missing value after option: --module.' "$stderr_file"; then
  echo 'Expected a missing-value diagnostic for --module' >&2
  cat "$stderr_file" >&2
  exit 1
fi
