#!/bin/sh
set -eu

root=$(git rev-parse --show-toplevel)
cd "$root"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/premise-staged-swiftlint.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
result=0

for path in "$@"; do
	case "$path" in
	*.swift) ;;
	*) continue ;;
	esac
	case "/$path/" in
	*'/../'*|*'/./'*|//*|*'//'*)
		printf 'Invalid staged path: %s\n' "$path" >&2
		exit 1 ;;
	esac
	metadata=$(git --literal-pathspecs ls-files --stage -- "$path" | awk 'NR == 1 { print $1, $3 }')
	[ -n "$metadata" ] || continue
	stage=${metadata#* }
	if [ "$stage" != 0 ]; then
		printf 'Cannot lint conflicted path: %s\n' "$path" >&2
		exit 1
	fi
	file_dir=$(mktemp -d "$temp_dir/file.XXXXXX")
	mkdir -p "$file_dir/$(dirname "$path")"
	git show ":$path" >"$file_dir/$path"
	ruby - "$path" "$file_dir" <<'RUBY'
require 'yaml'
require 'pathname'
require 'open3'
require 'fileutils'

path, destination = ARGV

def staged_file(path, required: false)
  output, status = Open3.capture2('git', '--literal-pathspecs', 'ls-files', '--stage', '-z', '--', path)
  abort "Cannot inspect staged config: #{path}" unless status.success?
  entries = output.split("\0")
  if entries.empty?
    abort "Missing staged config: #{path}" if required
    return nil
  end
  metadata, = entries.first.split("\t", 2)
  mode, oid, stage = metadata.split
  abort "Cannot use conflicted config: #{path}" if entries.length != 1 || stage != '0'
  abort "Cannot use non-regular config: #{path}" unless %w[100644 100755].include?(mode)
  data, status = Open3.capture2('git', 'cat-file', 'blob', oid)
  abort "Cannot read staged config: #{path}" unless status.success?
  data
end

configs = []
directory = File.dirname(path)
loop do
  config = directory == '.' ? '.swiftlint.yml' : "#{directory}/.swiftlint.yml"
  configs << config if staged_file(config)
  break if directory == '.'
  directory = File.dirname(directory)
end
abort 'Staged root .swiftlint.yml is required.' unless configs.include?('.swiftlint.yml')

visited = {}
visit = lambda do |config|
  abort "Config inheritance cycle: #{config}" if visited[config] == :visiting
  return if visited[config] == :done
  visited[config] = :visiting
  content = staged_file(config, required: true)
  begin
    yaml = YAML.safe_load(content, aliases: true)
  rescue Psych::Exception => e
    abort "Invalid staged config #{config}: #{e.message}"
  end
  abort "Invalid staged config: #{config}" unless yaml.is_a?(Hash)
  abort "Unsupported child_config in staged config: #{config}" if yaml.key?('child_config')
  if yaml.key?('parent_config')
    parent = yaml['parent_config']
    unless parent.is_a?(String) && !parent.empty? && !parent.start_with?('/') && !parent.match?(/\A[a-zA-Z][a-zA-Z0-9+.-]*:/)
      abort "Invalid parent_config in staged config: #{config}"
    end
    resolved = Pathname.new(File.join(File.dirname(config), parent)).cleanpath.to_s
    if resolved == '..' || resolved.start_with?('../') || resolved == '.'
      abort "Invalid parent_config traversal in staged config: #{config}"
    end
    visit.call(resolved)
  end
  target = File.join(destination, config)
  FileUtils.mkdir_p(File.dirname(target))
  File.binwrite(target, content)
  visited[config] = :done
end
configs.each { |config| visit.call(config) }
File.write(File.join(destination, 'selected-config'), configs.first)
RUBY
	config=$(cat "$file_dir/selected-config")
	lint_status=0
	swiftlint lint --strict --quiet --config "$file_dir/$config" \
		"$file_dir/$path" >"$file_dir/output" 2>&1 || lint_status=$?
	TEMP_FILE="$file_dir/$path" ORIGINAL_FILE="$path" \
		perl -pe 's/\Q$ENV{TEMP_FILE}\E/$ENV{ORIGINAL_FILE}/g' "$file_dir/output"
	if [ "$lint_status" -ne 0 ]; then
		result=1
	fi
done
exit "$result"
