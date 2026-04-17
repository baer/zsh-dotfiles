#!/bin/sh
#
# Claude Code
#
# Symlink the personal CLAUDE.md into ~/.claude/

CLAUDE_CONFIG_DIR="$HOME/.claude"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

mkdir -p "$CLAUDE_CONFIG_DIR"

if [ -f "$CLAUDE_CONFIG_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_CONFIG_DIR/CLAUDE.md" ]; then
  echo "  Backing up existing CLAUDE.md to $CLAUDE_CONFIG_DIR/CLAUDE.md.backup"
  mv "$CLAUDE_CONFIG_DIR/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md.backup"
fi

if [ ! -L "$CLAUDE_CONFIG_DIR/CLAUDE.md" ]; then
  ln -s "$DOTFILES_ROOT/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  echo "  Linked CLAUDE.md"
fi
