#===============================================================
#
# ALIASES AND FUNCTIONS
#
#===============================================================

# Allow aliases to be with sudo
alias sudo="sudo "

# Easier navigation: .., ...
alias ..="cd .."
alias ...="cd ../.."

# Shortcuts
alias reload!='. ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'

# Start an HTTP server in the current directory
serve() {
  local port="${1:-8000}"
  if (( $+commands[npx] )); then
    npx -y serve -l "${port}" -o
  else
    open "http://localhost:${port}/"
    python3 -m http.server "${port}"
  fi
}

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"

# Copy my public key to the pasteboard
alias pubkey="pbcopy < ~/.ssh/id_ed25519.pub && printf '=> Public key copied to pasteboard.\n'"

# Print the gzipped size of the contents of the clipboard
alias gsize="pbpaste | gzip | wc -c"

# Update forked repo from upstream
unalias updatefork 2>/dev/null
updatefork() {
  local branch
  branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')" \
    || { echo "updatefork: could not detect default branch (try: git remote set-head origin --auto)" >&2; return 1; }
  git switch "$branch" && git pull upstream "$branch"
}

# ----------------------------------------------------------------------
# Safeguards
# ----------------------------------------------------------------------

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# -> Prevents accidentally clobbering files.
alias mkdir='mkdir -p'

# ----------------------------------------------------------------------
# Git TUI
# ----------------------------------------------------------------------

if (( $+commands[lazygit] )); then
  alias lg="lazygit"
fi

# ----------------------------------------------------------------------
# ls / cat replacements
# ----------------------------------------------------------------------

if (( $+commands[eza] )); then
  alias ls="eza -F"
  alias ll="eza -laF --group-directories-first --sort=extension"
  alias tree="eza --tree"
elif (( $+commands[gls] )); then
  alias ls="gls -F --color"
  alias ll="gls -alF --color --group-directories-first --sort=extension"
fi

if (( $+commands[bat] )); then
  alias cat="bat --paging=never"
  export BAT_THEME="ansi"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
