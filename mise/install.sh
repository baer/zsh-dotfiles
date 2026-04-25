#!/bin/sh
# Symlink mise config to XDG location
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
dir="$(cd "$(dirname "$0")" && pwd)"
src="$dir/config.toml"
dst="$config_home/mise/config.toml"

mkdir -p "$config_home/mise"

if [ ! -L "$dst" ] || [ "$(readlink "$dst")" != "$src" ]; then
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.backup"
    echo "  Backed up existing mise config to $dst.backup"
  fi

  ln -sf "$src" "$dst"
  echo "  Linked mise config"
fi

# Trust and install tools if mise is available
if command -v mise >/dev/null 2>&1; then
  mise trust "$dst"
  mise install --yes
fi
