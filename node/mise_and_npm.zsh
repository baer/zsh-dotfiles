# Mise is activated by ~/.gusto/init.sh on work machines.
# On personal machines, activate it here if not already done.
if [[ -z "$_GUSTO_CONFIG_FILES_INITIALIZED" ]]; then
  if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
  fi
fi

# Semver is aspirational — set once, not every shell startup
if [[ ! -f ${XDG_CACHE_HOME:-$HOME/.cache}/npm-save-exact-set ]] && command -v npm &>/dev/null; then
  npm config set save-exact true
  mkdir -p ${XDG_CACHE_HOME:-$HOME/.cache}
  touch ${XDG_CACHE_HOME:-$HOME/.cache}/npm-save-exact-set
fi
