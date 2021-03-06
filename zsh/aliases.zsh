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

# View HTTP traffic
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"

# Copy my public key to the pasteboard
alias pubkey="more ~/.ssh/id_rsa.pub | pbcopy | printf '=> Public key copied to pasteboard.\n'"

# Print the gzipped size of the contents of the clipboard
alias gsize="pbpaste | gzip | wc -c"

# Update forked repo from upstream
alias updatefork="git fetch upstream && git checkout master && git rebase upstream/master"

# ----------------------------------------------------------------------
# Safeguards
# ----------------------------------------------------------------------

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# -> Prevents accidentally clobbering files.
alias mkdir='mkdir -p'

# ----------------------------------------------------------------------
# ls less With DIRCOLORS
# ----------------------------------------------------------------------
# ref: http://ss64.com/osx/ls.html

# grc overides for ls
#   Made possible through contributions from generous benefactors like
#   `brew install coreutils`
if $(gls &>/dev/null)
then
  alias ls="gls -F --color"
fi

# List all files colorized in long format
alias ll="ls -alF --group-directories-first --sort=extension"
