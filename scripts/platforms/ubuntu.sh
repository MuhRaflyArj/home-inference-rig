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

detect_cuda_arch() {
  command -v nvidia-smi >/dev/null 2>&1 || die "nvidia-smi not found. Install NVIDIA driver first."
  local cap
  cap="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n1 | tr -d '[:space:]')"
  [[ -n "$cap" ]] || die "Could not detect GPU compute capability via nvidia-smi"
  echo "${cap//./}"
}

resolve_nvcc() {
  if [[ -x /usr/local/cuda/bin/nvcc ]]; then
    echo "/usr/local/cuda/bin/nvcc"
  elif command -v nvcc >/dev/null 2>&1; then
    command -v nvcc
  else
    die "nvcc not found. Install cuda-toolkit-13-2 first."
  fi
}

preflight_ubuntu() {
  local cuda_arch nvcc_bin nvcc_ver major minor
  cuda_arch="$(detect_cuda_arch)"
  nvcc_bin="$(resolve_nvcc)"
  nvcc_ver="$("$nvcc_bin" --version | sed -n 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/p')"
  major="${nvcc_ver%%.*}"
  minor="${nvcc_ver##*.}"

  log "Detected GPU compute capability: sm_${cuda_arch}, nvcc: ${nvcc_bin} (${nvcc_ver})"

  if (( cuda_arch >= 120 )) && (( major < 12 || (major == 12 && minor < 8) )); then
    die "sm_${cuda_arch} requires CUDA >= 12.8 (recommended 13.2), found ${nvcc_ver} at ${nvcc_bin}."
  fi

  if systemctl is-active --quiet ollama.service 2>/dev/null; then
    warn "ollama.service is active and may contend for VRAM. Disable it with: sudo systemctl disable --now ollama.service"
  fi
}

install_apt_deps() {
  local pkgs=(build-essential ninja-build pkg-config libcurl4-openssl-dev ffmpeg)
  local missing=()
  for p in "${pkgs[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if (( ${#missing[@]} > 0 )); then
    log "Installing missing apt packages: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  fi
}

main() {
  preflight_ubuntu
  "$CHECK_ONLY" && { log "Pre-flight check passed."; exit 0; }

  ensure_dirs_and_path
  install_apt_deps

  local cuda_arch nvcc_bin
  cuda_arch="$(detect_cuda_arch)"
  nvcc_bin="$(resolve_nvcc)"

  if [[ -d /usr/local/cuda/lib64 ]]; then
    export CUDA_HOME=/usr/local/cuda
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
  fi

  if ! "$SKIP_BUILD"; then
    git_sync "https://github.com/ggml-org/llama.cpp.git" "$HOME/src/llama.cpp"
    cmake_build_and_link "$HOME/src/llama.cpp" "llama-server llama-cli" \
      -DCMAKE_CUDA_COMPILER="$nvcc_bin" \
      -DGGML_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES="$cuda_arch"

    git_sync "https://github.com/leejet/stable-diffusion.cpp.git" "$HOME/src/stable-diffusion.cpp" --recursive
    cmake_build_and_link "$HOME/src/stable-diffusion.cpp" "" \
      -DCMAKE_CUDA_COMPILER="$nvcc_bin" \
      -DSD_CUDA=ON \
      -DSD_BUILD_EXAMPLES=ON \
      -DCMAKE_CUDA_ARCHITECTURES="$cuda_arch"
  fi

  install_llama_swap
  install_fnm_node22

  log "Ubuntu setup complete. Run $SCRIPTS_DIR/checks/host.sh to verify."
}

main
