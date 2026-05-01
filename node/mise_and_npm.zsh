# Always run full mise activation, even on work machines where ~/.gusto/init.sh
# already ran `mise activate --shims`. Shims-only mode just puts mise's shim dir
# on PATH; it doesn't install the chpwd hook, so anything prepended afterward
# (e.g. /opt/homebrew/bin) shadows mise versions. Full activation re-prepends
# mise's resolved paths on every prompt and is idempotent over shims mode.
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi