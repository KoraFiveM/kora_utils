#!/usr/bin/env bash
# Runs every smoke test under test/smoke/ with plain Lua (no busted/luarocks
# dependency) and exits non-zero if any of them failed.
set -uo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lua_bin="${LUA:-lua}"

status=0

for file in "$dir"/smoke/*.lua; do
    echo "== $(basename "$file" .lua) =="
    if ! "$lua_bin" "$file"; then
        status=1
    fi
    echo
done

echo "== no_raw_print =="
(cd "$dir/.." && "${lua_bin:-lua}" test/no_raw_print.lua) || status=1

exit "$status"
