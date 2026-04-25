#!/usr/bin/env bash
#
# localrc.sh — managed ~/.localrc block helpers
#
# Source this file; do not execute it directly.

# Source guard
[[ -n "${_LOCALRC_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_LOCALRC_SH_LOADED=1

_LOCALRC_BEGIN_MARKER="# >>> dotfiles localrc >>>"
_LOCALRC_END_MARKER="# <<< dotfiles localrc <<<"

_localrc_path() {
  printf '%s\n' "${LOCALRC_PATH:-$HOME/.localrc}"
}

_localrc_decode_value() {
  local raw="$1"

  if [[ "$raw" == '"'*'"' ]]; then
    raw="${raw#\"}"
    raw="${raw%\"}"
    raw="${raw//\\\\/\\}"
    raw="${raw//\\\"/\"}"
  fi

  printf '%s' "$raw"
}

_localrc_encode_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

_localrc_export_line() {
  local var="$1" value="$2"
  printf 'export %s="%s"\n' "$var" "$(_localrc_encode_value "$value")"
}

_localrc_list_managed_lines() {
  local file="${1:-$(_localrc_path)}"
  [[ -f "$file" ]] || return 0

  awk -v begin="$_LOCALRC_BEGIN_MARKER" -v end="$_LOCALRC_END_MARKER" '
    $0 == begin { inblock = 1; next }
    $0 == end { inblock = 0; next }
    inblock { print }
  ' "$file"
}

_localrc_get_managed_value() {
  local var="$1" file="${2:-$(_localrc_path)}"
  local raw

  raw="$(
    awk -v begin="$_LOCALRC_BEGIN_MARKER" -v end="$_LOCALRC_END_MARKER" -v var="$var" '
      $0 == begin { inblock = 1; next }
      $0 == end { inblock = 0; next }
      inblock && $0 ~ ("^export " var "=") {
        sub("^export " var "=", "", $0)
        print
        exit
      }
    ' "$file" 2>/dev/null
  )"

  [[ -n "$raw" ]] || return 1
  _localrc_decode_value "$raw"
}

_localrc_get_unmanaged_value() {
  local var="$1" file="${2:-$(_localrc_path)}"
  local raw

  raw="$(
    awk -v begin="$_LOCALRC_BEGIN_MARKER" -v end="$_LOCALRC_END_MARKER" -v var="$var" '
      $0 == begin { inblock = 1; next }
      $0 == end { inblock = 0; next }
      !inblock && $0 ~ ("^export " var "=") {
        sub("^export " var "=", "", $0)
        print
        exit
      }
    ' "$file" 2>/dev/null
  )"

  [[ -n "$raw" ]] || return 1
  _localrc_decode_value "$raw"
}

_localrc_has_unmanaged_var() {
  local var="$1" file="${2:-$(_localrc_path)}"
  _localrc_get_unmanaged_value "$var" "$file" >/dev/null
}

_localrc_write_managed_lines() {
  local file="$1"
  shift

  local temp_file temp_block
  temp_file="$(mktemp)"
  temp_block="$(mktemp)"

  if [[ $# -eq 0 ]]; then
    if [[ -f "$file" ]]; then
      awk -v begin="$_LOCALRC_BEGIN_MARKER" -v end="$_LOCALRC_END_MARKER" '
        $0 == begin { inblock = 1; next }
        $0 == end { inblock = 0; next }
        !inblock { print }
      ' "$file" > "$temp_file"
    else
      : > "$temp_file"
    fi

    mv "$temp_file" "$file"
    rm -f "$temp_block"
    return 0
  fi

  {
    printf '%s\n' "$_LOCALRC_BEGIN_MARKER"
    printf '%s\n' "$@"
    printf '%s\n' "$_LOCALRC_END_MARKER"
  } > "$temp_block"

  if [[ -f "$file" ]]; then
    awk -v begin="$_LOCALRC_BEGIN_MARKER" -v end="$_LOCALRC_END_MARKER" '
      FNR == NR {
        block = block $0 ORS
        next
      }
      $0 == begin {
        if (length(block) > 0) {
          printf "%s", block
          printed += split(block, _lines, ORS) - 1
        }
        inblock = 1
        replaced = 1
        next
      }
      $0 == end {
        inblock = 0
        next
      }
      !inblock {
        print
        printed++
      }
      END {
        if (!replaced && length(block) > 0) {
          if (printed > 0) {
            printf "\n"
          }
          printf "%s", block
        }
      }
    ' "$temp_block" "$file" > "$temp_file"
  elif [[ $# -gt 0 ]]; then
    cp "$temp_block" "$temp_file"
  else
    : > "$temp_file"
  fi

  mv "$temp_file" "$file"
  rm -f "$temp_block"
}

_localrc_set_managed_var() {
  local var="$1" value="$2" file="${3:-$(_localrc_path)}"
  local line found=false
  local managed_lines=()

  while IFS= read -r line; do
    if [[ "$line" == "export $var="* ]]; then
      if [[ "$found" == false ]]; then
        managed_lines+=("$(_localrc_export_line "$var" "$value")")
        found=true
      fi
    elif [[ -n "$line" ]]; then
      managed_lines+=("$line")
    fi
  done < <(_localrc_list_managed_lines "$file")

  if [[ "$found" == false ]]; then
    managed_lines+=("$(_localrc_export_line "$var" "$value")")
  fi

  _localrc_write_managed_lines "$file" "${managed_lines[@]}"
}

_localrc_unset_managed_var() {
  local var="$1" file="${2:-$(_localrc_path)}"
  local line
  local managed_lines=()

  while IFS= read -r line; do
    [[ "$line" == "export $var="* ]] && continue
    [[ -n "$line" ]] && managed_lines+=("$line")
  done < <(_localrc_list_managed_lines "$file")

  _localrc_write_managed_lines "$file" "${managed_lines[@]}"
}
