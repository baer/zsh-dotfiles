export STARSHIP_CONFIG=~/.starship
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
