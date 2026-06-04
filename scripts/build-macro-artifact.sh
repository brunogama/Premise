#!/usr/bin/env bash
#
# build-macro-artifact.sh
#
# Compiles PremiseMacrosPlugin from source for every supported
# platform/arch triple and packages the results into a
# PremiseMacrosPlugin.artifactbundle.zip ready for GitHub Releases.
#
# Usage:
#   ./scripts/build-macro-artifact.sh          # build for current host only
#   ./scripts/build-macro-artifact.sh --all     # cross-compile all targets (CI)
#
# Requirements:
#   - Swift 6.0+ toolchain
#   - PREMISE_MACRO_SOURCE=1 must be set (this script sets it)
#
# The script outputs:
#   .build/artifacts/PremiseMacrosPlugin.artifactbundle.zip
#   .build/artifacts/checksum.txt
#
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

export PREMISE_MACRO_SOURCE=1

ARTIFACT_NAME="PremiseMacrosPlugin"
BUILD_DIR=".build/artifacts"
BUNDLE_DIR="${BUILD_DIR}/${ARTIFACT_NAME}.artifactbundle"
ARTIFACT_VERSION="${PREMISE_MACRO_VERSION:-1.0.0}"

rm -rf "$BUNDLE_DIR" "${BUILD_DIR}/${ARTIFACT_NAME}.artifactbundle.zip"
mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

detect_host_triple() {
  local arch os
  arch="$(uname -m)"
  os="$(uname -s)"

  case "$os" in
    Darwin)
      case "$arch" in
        arm64) echo "macos-arm64" ;;
        x86_64) echo "macos-x86_64" ;;
        *) echo "macos-${arch}" ;;
      esac
      ;;
    Linux)
      case "$arch" in
        aarch64) echo "linux-arm64" ;;
        x86_64) echo "linux-x86_64" ;;
        *) echo "linux-${arch}" ;;
      esac
      ;;
    *)
      printf 'unsupported OS: %s\n' "$os" >&2
      exit 1
      ;;
  esac
}

swift_triple_for() {
  case "$1" in
    macos-arm64)   echo "arm64-apple-macosx" ;;
    macos-x86_64)  echo "x86_64-apple-macosx" ;;
    linux-arm64)   echo "aarch64-unknown-linux-gnu" ;;
    linux-x86_64)  echo "x86_64-unknown-linux-gnu" ;;
    *) printf 'unknown platform: %s\n' "$1" >&2; exit 1 ;;
  esac
}

# Build the macro plugin for a given platform key.
# On macOS we use --arch; on Linux we use --triple for cross-compilation.
build_plugin() {
  local platform="$1"
  local swift_triple
  swift_triple="$(swift_triple_for "$platform")"

  printf '→ Building %s for %s (%s)\n' "$ARTIFACT_NAME" "$platform" "$swift_triple"

  local build_args=(
    swift build
    --product "$ARTIFACT_NAME"
    --configuration release
    -Xswiftc -warnings-as-errors
  )

  # On macOS use --arch for universal-compatible builds.
  # On Linux use --triple for cross-compilation.
  case "$platform" in
    macos-arm64)  build_args+=(--arch arm64) ;;
    macos-x86_64) build_args+=(--arch x86_64) ;;
    linux-*)      build_args+=(--triple "$swift_triple") ;;
  esac

  "${build_args[@]}"

  # Locate the built binary by searching known paths.
  local bin_path=""
  local candidates=(
    # macOS --arch builds
    ".build/apple/Products/Release/${ARTIFACT_NAME}"
    # Standard release build
    "$(swift build --product "$ARTIFACT_NAME" --configuration release --show-bin-path 2>/dev/null)/${ARTIFACT_NAME}"
    # Linux cross-compile paths
    ".build/release/${ARTIFACT_NAME}"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      bin_path="$candidate"
      break
    fi
  done

  if [[ -z "$bin_path" ]]; then
    printf 'error: could not locate built binary for %s. Searched:\n' "$platform" >&2
    for c in "${candidates[@]}"; do printf '  - %s\n' "$c" >&2; done
    exit 1
  fi

  # Copy into the artifact bundle.
  local dest_dir="${BUNDLE_DIR}/${platform}/bin"
  mkdir -p "$dest_dir"
  cp "$bin_path" "${dest_dir}/${ARTIFACT_NAME}"
  chmod +x "${dest_dir}/${ARTIFACT_NAME}"

  # Strip debug symbols for smaller binary.
  if command -v strip &>/dev/null; then
    strip "${dest_dir}/${ARTIFACT_NAME}" 2>/dev/null || true
  fi

  printf '  ✓ %s → %s (%s)\n' "$platform" "${dest_dir}/${ARTIFACT_NAME}" \
    "$(du -h "${dest_dir}/${ARTIFACT_NAME}" | cut -f1)"
}

# ---------------------------------------------------------------------------
# Determine which platforms to build
# ---------------------------------------------------------------------------

PLATFORMS=()

if [[ "${1:-}" == "--all" ]]; then
  host_os="$(uname -s)"
  if [[ "$host_os" == "Darwin" ]]; then
    PLATFORMS=(macos-arm64 macos-x86_64)
  else
    PLATFORMS=(linux-x86_64)
  fi
  # Cross-compilation targets are added in CI via separate runner jobs.
else
  PLATFORMS=("$(detect_host_triple)")
fi

# ---------------------------------------------------------------------------
# Build each platform
# ---------------------------------------------------------------------------

printf '=== Building %s artifact bundle ===\n' "$ARTIFACT_NAME"
printf 'Platforms: %s\n' "${PLATFORMS[*]}"
printf 'Swift version: %s\n\n' "$(swift --version 2>&1 | head -1)"

for platform in "${PLATFORMS[@]}"; do
  build_plugin "$platform"
done

# ---------------------------------------------------------------------------
# Generate info.json
# ---------------------------------------------------------------------------

# Build the variants array for info.json.
variants_json=""
for platform in "${PLATFORMS[@]}"; do
  local_triple="$(swift_triple_for "$platform")"
  if [[ -n "$variants_json" ]]; then
    variants_json+=","
  fi
  variants_json+="
      {
        \"path\": \"${platform}/bin/${ARTIFACT_NAME}\",
        \"supportedTriples\": [\"${local_triple}\"]
      }"
done

cat > "${BUNDLE_DIR}/info.json" <<INFOJSON
{
  "schemaVersion": "1.0",
  "artifacts": {
    "${ARTIFACT_NAME}": {
      "version": "${ARTIFACT_VERSION}",
      "type": "executable",
      "variants": [${variants_json}
      ]
    }
  }
}
INFOJSON

printf '\n✓ info.json generated\n'

# ---------------------------------------------------------------------------
# Zip the bundle
# ---------------------------------------------------------------------------

cd "$BUILD_DIR"
zip -r -y "${ARTIFACT_NAME}.artifactbundle.zip" "${ARTIFACT_NAME}.artifactbundle"
cd "$repo_root"

# Compute checksum for Package.swift.
CHECKSUM="$(swift package compute-checksum "${BUILD_DIR}/${ARTIFACT_NAME}.artifactbundle.zip")"

printf '%s' "$CHECKSUM" > "${BUILD_DIR}/checksum.txt"

printf '\n=== Artifact bundle ready ===\n'
printf 'File:     %s/%s.artifactbundle.zip\n' "$BUILD_DIR" "$ARTIFACT_NAME"
printf 'Size:     %s\n' "$(du -h "${BUILD_DIR}/${ARTIFACT_NAME}.artifactbundle.zip" | cut -f1)"
printf 'Checksum: %s\n' "$CHECKSUM"
printf '\nUpdate Package.swift binaryTarget checksum to:\n'
printf '  checksum: "%s"\n' "$CHECKSUM"
