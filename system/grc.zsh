# GRC colorizes nifty unix tools all over the place
if is_macos && (( $+commands[grc] )) && (( $+commands[brew] ))
then
  source $HOMEBREW_PREFIX/etc/grc.zsh
fi
