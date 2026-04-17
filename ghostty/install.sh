#!/bin/sh
#
# Ghostty
#
# Symlink the Ghostty config into ~/.config/ghostty/

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

mkdir -p "$GHOSTTY_CONFIG_DIR"

if [ -f "$GHOSTTY_CONFIG_DIR/config" ] && [ ! -L "$GHOSTTY_CONFIG_DIR/config" ]; then
  echo "  Backing up existing Ghostty config to $GHOSTTY_CONFIG_DIR/config.backup"
  mv "$GHOSTTY_CONFIG_DIR/config" "$GHOSTTY_CONFIG_DIR/config.backup"
fi

if [ ! -L "$GHOSTTY_CONFIG_DIR/config" ]; then
  ln -s "$DOTFILES_ROOT/ghostty/config" "$GHOSTTY_CONFIG_DIR/config"
  echo "  Linked Ghostty config"
fi
