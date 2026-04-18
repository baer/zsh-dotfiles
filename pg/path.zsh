[[ "$(uname -s)" == "Darwin" ]] || return 0

# Add the latest Homebrew-installed PostgreSQL to PATH
local pg_dirs=(/opt/homebrew/opt/postgresql@*(nOn))
[[ -n "$pg_dirs" ]] && export PATH="${pg_dirs[1]}/bin:$PATH"
