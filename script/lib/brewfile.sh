#!/usr/bin/env bash
#
# brewfile.sh — Brewfile parsing and mutation
#
# Source this file; do not execute it directly.
# Requires BREWFILE to be set by the caller.
# Provides _brewfile_list_section, _brewfile_contains, _brewfile_insert.

# Source guard
[[ -n "${_BREWFILE_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_BREWFILE_SH_LOADED=1

# List names in a Brewfile section, one per line.
# Args: type ("tap"|"brew"|"cask"|"mas")
_brewfile_list_section() {
  local type="$1"
  [[ -f "$BREWFILE" ]] || return 0
  if [[ "$type" == "mas" ]]; then
    grep "^mas '" "$BREWFILE" | awk -F"'" '{print $2}'
  else
    grep "^${type} '" "$BREWFILE" | awk -F"'" '{print $2}'
  fi
}

# Check if a package is in the Brewfile.
# Args: type ("tap"|"brew"|"cask"|"mas"), name (for mas: numeric id)
# Returns 0 if present, 1 if not.
_brewfile_contains() {
  local type="$1" name="$2"
  [[ -f "$BREWFILE" ]] || return 1
  if [[ "$type" == "mas" ]]; then
    grep -q "id: ${name}$" "$BREWFILE"
  else
    grep -qx "${type} '${name}'" "$BREWFILE"
  fi
}

# Insert a line into the Brewfile in the correct section, alphabetically sorted.
# Args: type ("tap"|"brew"|"cask"|"mas"), name [, id (required for mas)]
_brewfile_insert() {
  local type="$1" name="$2"
  local line

  if [[ "$type" == "mas" ]]; then
    local id="$3"
    line="mas '${name}', id: ${id}"
  else
    line="${type} '${name}'"
  fi

  local section_pattern="^${type} '"
  local last_section_line
  last_section_line="$(grep -n "$section_pattern" "$BREWFILE" 2>/dev/null | tail -1 | cut -d: -f1)"

  if [[ -z "$last_section_line" ]]; then
    # Section doesn't exist — append with blank line separator
    echo "" >> "$BREWFILE"
    echo "$line" >> "$BREWFILE"
  else
    # Find correct alphabetical position within section
    local inserted=false
    local tmp
    tmp="$(mktemp)"
    while IFS= read -r existing; do
      if [[ "$inserted" == false ]] && [[ "$existing" =~ ^${type}\ \' ]]; then
        local existing_name
        existing_name="$(echo "$existing" | awk -F"'" '{print $2}')"
        if [[ "$name" < "$existing_name" ]]; then
          echo "$line" >> "$tmp"
          inserted=true
        fi
      fi
      echo "$existing" >> "$tmp"
    done < "$BREWFILE"

    if [[ "$inserted" == false ]]; then
      # Append after the last entry in the section
      sed -i '' "${last_section_line}a\\
${line}
" "$BREWFILE"
    else
      mv "$tmp" "$BREWFILE"
    fi
    rm -f "$tmp"
  fi

  log_success "Added $line to Brewfile"
}
