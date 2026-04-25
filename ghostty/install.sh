#!/bin/sh
#
# Ghostty
#
# Symlink the Ghostty config into ~/.config/ghostty/

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
src="$DOTFILES_ROOT/ghostty/config"
dst="$GHOSTTY_CONFIG_DIR/config"

mkdir -p "$GHOSTTY_CONFIG_DIR"

if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
  exit 0
fi

if [ -f "$dst" ] && [ ! -L "$dst" ]; then
  echo "  Backing up existing Ghostty config to $dst.backup"
  mv "$dst" "$dst.backup"
fi

ln -sf "$src" "$dst"
