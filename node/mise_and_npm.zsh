# Mise is activated by ~/.gusto/init.sh on work machines.
# On personal machines, activate it here if not already done.
if [[ -z "$_GUSTO_CONFIG_FILES_INITIALIZED" ]]; then
  if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
  fi
fi

# Semver is aspirational — set once, not every shell startup
if command -v npm &>/dev/null && [[ "$(npm config get save-exact 2>/dev/null)" != "true" ]]; then
  npm config set save-exact true
fi
