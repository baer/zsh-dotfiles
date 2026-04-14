# GRC colorizes nifty unix tools all over the place
if (( $+commands[grc] )) && (( $+commands[brew] ))
then
  source $HOMEBREW_PREFIX/etc/grc.zsh
fi
