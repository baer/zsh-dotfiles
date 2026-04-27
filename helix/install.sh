#!/bin/sh
#
# Helix
#
# Symlink the Helix config into $XDG_CONFIG_HOME/helix/config.toml.

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dir="$config_home/helix"
DOTFILES_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
src="$DOTFILES_ROOT/helix/config.toml"
dst="$config_dir/config.toml"
old_vimrc_src="$DOTFILES_ROOT/vim/vimrc.symlink"

if [ -L "$HOME/.vimrc" ] && [ "$(readlink "$HOME/.vimrc")" = "$old_vimrc_src" ]; then
  rm "$HOME/.vimrc"
fi

mkdir -p "$config_dir"

if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
  exit 0
fi

if [ -f "$dst" ] && [ ! -L "$dst" ]; then
  echo "  Backing up existing Helix config to $dst.backup"
  mv "$dst" "$dst.backup"
fi

ln -sf "$src" "$dst"
