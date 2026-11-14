#!/usr/bin/env bash
set -euo pipefail

log() { printf '[setup] %s\n' "$*"; }
warn() { printf '[setup] WARN: %s\n' "$*" >&2; }
die() { printf '[setup] ERROR: %s\n' "$*" >&2; exit 1; }

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) die "Unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
}

ensure_dirs_and_path() {
  mkdir -p "$HOME/src" "$HOME/models/llm" "$HOME/models/image" "$HOME/models/tts" "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  local rc_file="$HOME/.bashrc"
  [[ "$(detect_os)" == "darwin" ]] && rc_file="$HOME/.zshrc"
  if [[ -f "$rc_file" ]] && ! grep -q '\.local/bin' "$rc_file"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc_file"
  fi
}

git_sync() {
  local url="$1" dir="$2" recursive="${3:-}"
  if [[ -d "$dir/.git" ]]; then
    log "Updating $dir"
    git -C "$dir" pull --ff-only
    [[ "$recursive" == "--recursive" ]] && git -C "$dir" submodule update --init --recursive
  else
    log "Cloning $url -> $dir"
    if [[ "$recursive" == "--recursive" ]]; then
      git clone --recursive "$url" "$dir"
    else
      git clone "$url" "$dir"
    fi
  fi
}

cmake_build_and_link() {
  local src_dir="$1" targets="$2"
  shift 2
  local cmake_flags=("$@")

  cd "$src_dir"
  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release "${cmake_flags[@]}"

  if [[ -n "$targets" ]]; then
    # shellcheck disable=SC2086
    cmake --build build --config Release -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)" --target $targets
    for t in $targets; do
      ln -sf "$src_dir/build/bin/$t" "$HOME/.local/bin/$t"
    done
  else
    cmake --build build --config Release -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
    for bin in sd-server sd-cli; do
      [[ -x "$src_dir/build/bin/$bin" ]] && ln -sf "$src_dir/build/bin/$bin" "$HOME/.local/bin/$bin"
    done
  fi
}

install_llama_swap() {
  local os arch version tmp_dir url
  os="$(detect_os)"
  arch="$(detect_arch)"

  version="$(curl -fsSL https://api.github.com/repos/mostlygeek/llama-swap/releases/latest \
    | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"
  [[ -n "$version" ]] || die "Failed to resolve latest llama-swap version"

  tmp_dir="$(mktemp -d)"
  url="https://github.com/mostlygeek/llama-swap/releases/download/${version}/llama-swap_${version#v}_${os}_${arch}.tar.gz"

  log "Installing llama-swap $version (${os}_${arch})"
  curl -fsSL -o "$tmp_dir/llama-swap.tar.gz" "$url"
  tar -xzf "$tmp_dir/llama-swap.tar.gz" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/llama-swap" "$HOME/.local/bin/llama-swap"
  rm -rf "$tmp_dir"
}

install_fnm_node22() {
  if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
    log "Installing fnm"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  fi

  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"
  fnm install 22
  fnm default 22
  fnm use 22

  local fnm_bin
  fnm_bin="$(dirname "$(fnm exec --using=22 which node)")"
  ln -sfn "$fnm_bin/node" "$HOME/.local/bin/node"
  ln -sfn "$fnm_bin/npm" "$HOME/.local/bin/npm"
  ln -sfn "$fnm_bin/npx" "$HOME/.local/bin/npx"
}
