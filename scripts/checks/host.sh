#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPTS_DIR/lib/common.sh"

OS="$(detect_os)"
export PATH="$HOME/.local/bin:$PATH"
[[ -d /usr/local/cuda/bin ]] && export PATH="/usr/local/cuda/bin:$PATH"
[[ -d /usr/local/cuda/lib64 ]] && export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

echo "=== Directories ==="
ls -ld "$HOME/src" "$HOME/models/llm" "$HOME/models/image" "$HOME/models/tts" "$HOME/.local/bin"

echo "=== Binaries ==="
llama-server --version
sd-server --help | sed -n '1,5p'
llama-swap --version

echo "=== Media & Node 22 ==="
ffmpeg -version | sed -n '1p'
ffprobe -version | sed -n '1p'
node_ver="$(env -i HOME="$HOME" PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" node -v)"
echo "node: $node_ver"
[[ "$node_ver" == v22.* ]] || die "Expected Node v22.x, found $node_ver"

if [[ "$OS" == "linux" ]]; then
  echo "=== Ubuntu CUDA & Ollama ==="
  echo "ollama active: $(systemctl is-active ollama.service 2>/dev/null || echo inactive)"
  nvcc --version
  nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv
  for bin in llama-server sd-server; do
    bin_path="$(readlink -f "$(command -v "$bin")")"
    ldd_out="$(ldd "$bin_path")"
    echo "$ldd_out" | grep -E "cuda|cublas" || true
    if echo "$ldd_out" | grep -q "not found"; then
      die "Missing shared library in $bin ($bin_path)"
    fi
  done
  command -v docker >/dev/null 2>&1 || die "docker not found"
  docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
  echo "=== macOS Metal Linking ==="
  otool -L "$(command -v llama-server)" | grep -i metal || true
fi
