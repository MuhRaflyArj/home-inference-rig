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
env -i HOME="$HOME" PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" node -v

if [[ "$OS" == "linux" ]]; then
  echo "=== Ubuntu CUDA & Ollama ==="
  echo "ollama active: $(systemctl is-active ollama.service 2>/dev/null || echo inactive)"
  nvcc --version
  nvidia-smi --query-gpu=name,compute_cap,memory.total,driver_version --format=csv
  ldd "$(readlink -f "$HOME/.local/bin/llama-server")" | grep -E "cuda|cublas|not found" || true
  ldd "$(readlink -f "$HOME/.local/bin/sd-server")" | grep -E "cuda|cublas|not found" || true
  if command -v docker >/dev/null 2>&1; then
    docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
  fi
else
  echo "=== macOS Metal Linking ==="
  otool -L "$(readlink -f "$HOME/.local/bin/llama-server")" | grep -i metal || true
fi
