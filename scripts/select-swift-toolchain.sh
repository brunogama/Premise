#!/usr/bin/env bash
# Deterministic Swift toolchain selection with failing version assertions.
#
# Probes every installed Xcode for the Swift version it actually ships and
# selects the newest one matching the requested MAJOR.MINOR. Never guesses
# from Xcode marketing versions and never continues on a mismatch.
#
# Usage:
#   scripts/select-swift-toolchain.sh <major.minor>
#     Select a matching Xcode. Exports DEVELOPER_DIR to $GITHUB_ENV when
#     running in GitHub Actions and prints an `export` line for local use.
#
#   scripts/select-swift-toolchain.sh --assert-only <major.minor>
#     Assert that the active `swift` already reports the requested version.
#     Used on Linux containers and as a post-selection guard on macOS.
#
# Exit codes: 0 success, 1 version failure, 2 usage error.

set -euo pipefail

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

fail() {
  echo "error: $*" >&2
  exit 1
}

# Prints the MAJOR.MINOR[.PATCH] Swift version for the given developer
# directory, or for the active `swift` when the argument is empty.
swift_version_for() {
  local developer_dir="$1" output=""
  if [[ -n "$developer_dir" ]]; then
    output="$(DEVELOPER_DIR="$developer_dir" /usr/bin/xcrun swift --version 2>/dev/null)" || return 1
  else
    output="$(swift --version 2>&1)" || return 1
  fi
  sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' <<<"$output" | head -n 1
}

# True when $1 (full version) matches $2 (required MAJOR.MINOR).
version_matches() {
  [[ "$1" == "$2" || "$1" == "$2".* ]]
}

assert_only=false
if [[ "${1:-}" == "--assert-only" ]]; then
  assert_only=true
  shift
fi

required="${1:-}"
[[ -n "$required" ]] || usage
if [[ ! "$required" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "error: required version must be MAJOR.MINOR, got: $required" >&2
  exit 2
fi

if $assert_only; then
  active="$(swift_version_for "")" \
    || fail "unable to run \`swift --version\`"
  [[ -n "$active" ]] || fail "could not parse \`swift --version\` output"
  version_matches "$active" "$required" \
    || fail "active Swift is $active, required $required"
  echo "asserted: active Swift $active matches required $required"
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] \
  || fail "toolchain selection requires macOS; use --assert-only on Linux"

# Enumerate installed Xcodes, resolving symlinks so aliases such as
# /Applications/Xcode.app -> Xcode-beta.app are probed once.
candidates=()
seen=$'\n'
for app in /Applications/Xcode*.app; do
  [[ -d "$app" ]] || continue
  resolved="$(readlink -f "$app")"
  case "$seen" in
    *$'\n'"$resolved"$'\n'*) continue ;;
  esac
  seen="${seen}${resolved}"$'\n'
  candidates+=("$resolved")
done
[[ ${#candidates[@]} -gt 0 ]] || fail "no Xcode installations found in /Applications"

matches=""
probed=""
for app in "${candidates[@]}"; do
  developer_dir="$app/Contents/Developer"
  version="$(swift_version_for "$developer_dir")" || continue
  [[ -n "$version" ]] || continue
  probed="${probed}  ${version}  ${app}"$'\n'
  if version_matches "$version" "$required"; then
    matches="${matches}${version}	${developer_dir}"$'\n'
  fi
done

if [[ -z "$matches" ]]; then
  {
    echo "error: no installed Xcode ships Swift $required"
    echo "probed toolchains:"
    printf '%s' "$probed"
  } >&2
  exit 1
fi

# Highest matching Swift version wins; ties resolve by path sort, which is
# stable for a given runner image.
selected_line="$(printf '%s' "$matches" | sort -V | tail -n 1)"
selected_version="${selected_line%%	*}"
selected_dir="${selected_line#*	}"

# Failing post-selection assertion: the selected toolchain must still report
# the required version when invoked through DEVELOPER_DIR.
verified="$(swift_version_for "$selected_dir")" \
  || fail "selected toolchain at $selected_dir failed to run swift"
version_matches "$verified" "$required" \
  || fail "selected toolchain reports Swift $verified, required $required"

echo "selected: Swift $selected_version at $selected_dir"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DEVELOPER_DIR=$selected_dir" >>"$GITHUB_ENV"
fi
echo "export DEVELOPER_DIR=\"$selected_dir\""
