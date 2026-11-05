#!/bin/sh
set -eu

root=$(git rev-parse --show-toplevel)
cd "$root"

staged_path_exists() {
  git diff --cached --name-only --diff-filter=ACMR -- "$1" | grep -Fqx -- "$1"
}

if staged_path_exists Package.swift; then
  swift package dump-package >/dev/null
fi

for path in .swiftlint.yml .swift-format; do
  if staged_path_exists "$path"; then
    case "$path" in
      .swiftlint.yml)
        swiftlint rules --config "$path" >/dev/null
        ;;
      .swift-format)
swift format lint --configuration "$path" >/dev/null
        ;;
    esac
  fi
done
