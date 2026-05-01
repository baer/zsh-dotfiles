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

# Trust and install tools if mise is available.
# Retry transient install failures — sharp's prebuilt binary downloads
# and other npm-backed installs are known to flake.
if command -v mise >/dev/null 2>&1; then
  mise trust "$dst"
  attempt=1
  while ! mise install --yes; do
    if [ "$attempt" -ge 3 ]; then
      echo "  mise install failed after $attempt attempts" >&2
      exit 1
    fi
    attempt=$((attempt + 1))
    echo "  mise install failed — retrying ($attempt/3)..." >&2
    sleep 2
  done
fi
