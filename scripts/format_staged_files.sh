#!/bin/sh
set -eu

root=$(git rev-parse --show-toplevel)
cd "$root"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/swift-harness-format.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
index=0

for path in "$@"; do
	metadata=$(git ls-files --stage -- "$path" | awk 'NR == 1 { print $1, $3 }')
	[ -n "$metadata" ] || continue
	mode=${metadata%% *}
	stage=${metadata#* }
	if [ "$stage" != 0 ]; then
		printf 'Cannot format conflicted path: %s\n' "$path" >&2
		exit 1
	fi
	case "$mode" in
	100644 | 100755) ;;
	*) continue ;;
	esac

	temp_file="$temp_dir/$index.swift"
	index=$((index + 1))
	git show ":$path" >"$temp_file"

	case "$path" in
	*.swift)
		swift format format --configuration .swift-format --in-place "$temp_file"
		;;
	esac

	if LC_ALL=C grep -Iq . "$temp_file"; then
		perl -0777 -pi -e 's/[ \t]+(?=\r?\n|\z)//g; $_ .= "\n" if length($_) && !/\n\z/' "$temp_file"
	fi

	old_blob=$(git rev-parse ":$path")
	new_blob=$(git hash-object -w "$temp_file")
	if [ "$new_blob" != "$old_blob" ]; then
		worktree_matches_index=true
		if ! git diff --quiet -- "$path"; then
			worktree_matches_index=false
		fi
		if [ "$worktree_matches_index" = true ]; then
			cp "$temp_file" "$path"
			git add -- "$path"
		else
			git update-index --cacheinfo "$mode,$new_blob,$path"
		fi
	fi
done
