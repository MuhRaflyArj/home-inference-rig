#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPTS_DIR/lib/common.sh"

CHECK_ONLY=false
SKIP_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    --skip-build) SKIP_BUILD=true ;;
    *) die "Unknown option: $arg" ;;
  esac
done

preflight_macos() {
  xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools missing. Run: xcode-select --install"
  command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install from https://brew.sh"
  log "macOS pre-flight passed ($(uname -m))"
}

install_brew_deps() {
  local pkgs=(cmake ninja ffmpeg fnm)
  local missing=()
  for p in "${pkgs[@]}"; do
    brew list "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if (( ${#missing[@]} > 0 )); then
    log "Installing Homebrew packages: ${missing[*]}"
    brew install "${missing[@]}"
  fi
}

main() {
  preflight_macos
  "$CHECK_ONLY" && { log "Pre-flight check passed."; exit 0; }

  ensure_dirs_and_path
  install_brew_deps

  if ! "$SKIP_BUILD"; then
    git_sync "https://github.com/ggml-org/llama.cpp.git" "$HOME/src/llama.cpp"
    cmake_build_and_link "$HOME/src/llama.cpp" "llama-server llama-cli" \
      -DGGML_METAL=ON

    git_sync "https://github.com/leejet/stable-diffusion.cpp.git" "$HOME/src/stable-diffusion.cpp" --recursive
    cmake_build_and_link "$HOME/src/stable-diffusion.cpp" "" \
      -DSD_METAL=ON \
      -DSD_BUILD_EXAMPLES=ON
  fi

  install_llama_swap
  install_fnm_node22

  log "macOS setup complete. Run $SCRIPTS_DIR/checks/host.sh to verify."
}

main
