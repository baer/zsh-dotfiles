# Tool initialization — ordered so keybindings don't clobber each other.
# fzf binds Ctrl+R; atuin re-binds it after, so atuin wins for history search.

# fzf fuzzy finder (Ctrl+T for files, Alt+C for dirs, Ctrl+R overridden by atuin below)
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# zoxide (smarter cd — use `z` to jump to frecent directories)
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# atuin (shell history) — must init after fzf so atuin keeps Ctrl+R
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi
