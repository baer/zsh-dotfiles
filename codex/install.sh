#!/bin/sh
#
# Codex
#
# Symlink the personal AGENTS.md into ~/.codex/

CODEX_CONFIG_DIR="$HOME/.codex"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

mkdir -p "$CODEX_CONFIG_DIR"

if [ -f "$CODEX_CONFIG_DIR/AGENTS.md" ] && [ ! -L "$CODEX_CONFIG_DIR/AGENTS.md" ]; then
  echo "  Backing up existing AGENTS.md to $CODEX_CONFIG_DIR/AGENTS.md.backup"
  mv "$CODEX_CONFIG_DIR/AGENTS.md" "$CODEX_CONFIG_DIR/AGENTS.md.backup"
fi

ln -sf "$DOTFILES_ROOT/codex/AGENTS.md" "$CODEX_CONFIG_DIR/AGENTS.md"
