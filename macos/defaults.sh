#!/bin/sh
# macOS sensible defaults
# Run manually: sh macos/defaults.sh
# Re-run after macOS updates (updates can reset these).

[ "$(uname -s)" = "Darwin" ] || exit 0

# Keyboard: fast key repeat rate
# KeyRepeat: lower = faster (default 6, minimum 1)
# InitialKeyRepeat: lower = shorter delay before repeat (default 68, minimum 15)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
