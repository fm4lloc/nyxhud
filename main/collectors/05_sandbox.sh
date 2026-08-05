#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

INTERVAL=5

set -u
set -f
LC_ALL=C
export LC_ALL
umask 077

NAME=${0##*/}
NAME=${NAME%.sh}
: "${NYXHUD_RENDER_DIR:?}"
[ -d "$NYXHUD_RENDER_DIR" ] || exit 1

MAX_ITEMS=${NYXHUD_SANDBOX_MAX:-8}
case $MAX_ITEMS in
    ''|*[!0-9]*|0) MAX_ITEMS=8 ;;
esac

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

if ! command -v firejail >/dev/null 2>&1; then
    printf 'SANDBOX\nMissing firejail\n' | publish
    exit 0
fi

LIST=$(firejail --list 2>/dev/null |
    awk -v max="$MAX_ITEMS" '
        {
            line = $0
            if (sub(/^.*[[:space:]]firejail[[:space:]]+/, "", line) == 0) next
            n = split(line, part, /[[:space:]]+/)
            name = ""
            for (i = 1; i <= n; i++) {
                if (part[i] ~ /^-/) continue
                sub(/^.*\//, "", part[i])
                name = part[i]
                break
            }
            if (name == "") next
            if (length(name) > 16) {
                name = substr(name, 1, 15)
                sub(/[\302-\364][\200-\277]*$/, "", name)
                name = name "~"
            }
            if (++count <= max) printf "%s%s", (count > 1 ? " " : ""), name
        }
        END {
            if (count > max) printf " +%d", count - max
            if (count > 0) printf "\n"
        }')

{
    printf 'SANDBOX\n'
    if [ -n "$LIST" ]; then
        printf 'Jails       %s\n' "$LIST"
    else
        printf 'Jails       none\n'
    fi
} | publish
