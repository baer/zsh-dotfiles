#!/bin/sh
# Symlink starship config to XDG location
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
src="$(cd "$(dirname "$0")" && pwd)/config"
dst="$config_home/starship.toml"

# Migrate: remove old ~/.starship symlink if it points to the old location
if [ -L "$HOME/.starship" ]; then
  rm "$HOME/.starship"
fi

mkdir -p "$config_home"

if [ -L "$dst" ]; then
  current="$(readlink "$dst")"
  if [ "$current" = "$src" ]; then
    exit 0  # already correct
  fi
fi

ln -sf "$src" "$dst"
