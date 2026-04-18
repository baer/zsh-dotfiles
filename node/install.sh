#!/bin/sh
# Pin npm installs to exact versions (no ^ or ~ prefixes)
if command -v npm >/dev/null 2>&1; then
  npm config set save-exact true
  echo "  Set npm save-exact=true"
fi
