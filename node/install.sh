#!/bin/sh
# Install global npm packages from npm-globals.txt
if ! command -v npm >/dev/null 2>&1; then
  exit 0
fi

dir="$(cd "$(dirname "$0")" && pwd)"

while IFS= read -r pkg || [ -n "$pkg" ]; do
  # Strip comments and whitespace
  pkg=$(echo "$pkg" | sed 's/#.*//' | tr -d '[:space:]')
  [ -z "$pkg" ] && continue
  if ! npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
    npm install -g "$pkg"
  fi
done < "$dir/npm-globals.txt"
