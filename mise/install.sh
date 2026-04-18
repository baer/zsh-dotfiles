#!/bin/sh
# Symlink mise config to XDG location
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
dir="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$config_home/mise"

if [ -f "$config_home/mise/config.toml" ] && [ ! -L "$config_home/mise/config.toml" ]; then
  mv "$config_home/mise/config.toml" "$config_home/mise/config.toml.backup"
  echo "  Backed up existing mise config to $config_home/mise/config.toml.backup"
fi

ln -sf "$dir/config.toml" "$config_home/mise/config.toml"
echo "  Linked mise config"

# Install tools if mise is available
if command -v mise >/dev/null 2>&1; then
  mise install
fi
