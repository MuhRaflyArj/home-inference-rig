#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$INSTALL_DIR/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPTS_DIR/lib/common.sh"

case "$(detect_os)" in
  linux) exec "$SCRIPTS_DIR/platforms/ubuntu.sh" "$@" ;;
  darwin) exec "$SCRIPTS_DIR/platforms/macos.sh" "$@" ;;
esac
