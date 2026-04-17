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

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"

# Copy my public key to the pasteboard
alias pubkey="pbcopy < ~/.ssh/id_ed25519.pub && printf '=> Public key copied to pasteboard.\n'"

# Print the gzipped size of the contents of the clipboard
alias gsize="pbpaste | gzip | wc -c"

# Update forked repo from upstream
alias updatefork="git checkout master && git pull upstream master"

# ----------------------------------------------------------------------
# Safeguards
# ----------------------------------------------------------------------

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# -> Prevents accidentally clobbering files.
alias mkdir='mkdir -p'

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
