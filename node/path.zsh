[[ "$(uname -s)" == "Darwin" ]] || return 0

# Export globally installed npm scripts
export PATH="$HOMEBREW_PREFIX/share/npm/bin:$PATH"
