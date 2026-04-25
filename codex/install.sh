#!/bin/sh
#
# Codex
#
# Symlink the personal AGENTS.md into ~/.codex/

CODEX_CONFIG_DIR="$HOME/.codex"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
src="$DOTFILES_ROOT/codex/AGENTS.md"
dst="$CODEX_CONFIG_DIR/AGENTS.md"

mkdir -p "$CODEX_CONFIG_DIR"

if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
  exit 0
fi

if [ -f "$dst" ] && [ ! -L "$dst" ]; then
  echo "  Backing up existing AGENTS.md to $dst.backup"
  mv "$dst" "$dst.backup"
fi

ln -sf "$src" "$dst"
