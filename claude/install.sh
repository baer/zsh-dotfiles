#!/bin/sh
#
# Claude Code
#
# Symlink the personal CLAUDE.md into ~/.claude/

CLAUDE_CONFIG_DIR="$HOME/.claude"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
src="$DOTFILES_ROOT/claude/CLAUDE.md"
dst="$CLAUDE_CONFIG_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_CONFIG_DIR"

if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
  exit 0
fi

if [ -f "$dst" ] && [ ! -L "$dst" ]; then
  echo "  Backing up existing CLAUDE.md to $dst.backup"
  mv "$dst" "$dst.backup"
fi

ln -sf "$src" "$dst"
