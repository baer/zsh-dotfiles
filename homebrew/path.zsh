[[ "$(uname -s)" == "Darwin" ]] || return 0

export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
