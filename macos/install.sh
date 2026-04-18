#!/bin/sh
# Apply macOS defaults during bootstrap
if [ "$(uname -s)" = "Darwin" ]; then
  dir="$(cd "$(dirname "$0")" && pwd)"
  sh "$dir/defaults.sh"
fi
