# Export node versions
export NVM_DIR="/Users/ebaer/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

# Export globally installed npm scripts
export PATH="$(brew --prefix)/share/npm/bin:$PATH"

# Export for Yarn
export PATH="$HOME/.yarn/bin:$PATH"
