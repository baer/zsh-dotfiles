# Platform detection helpers
# Available to all *.zsh files (loaded in the *.zsh pass).
# NOT available in path.zsh files (they load earlier) — use inline uname checks there.
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
