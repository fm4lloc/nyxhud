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
# firejail --list:  PID:user:name:cmdline   (>= 0.9.40)
#                   PID:user:cmdline        (versoes antigas)
# cmdline pode ser "/usr/bin/firejail --opt prog", "firejail prog"
# ou apenas "prog" quando o jail veio de symlink do firecfg.
LIST=$(firejail --list 2>/dev/null |
    awk -v max="$MAX_ITEMS" '
        /^[0-9]+:/ {
            line = $0
            jail = ""
            if (match(line, /^[0-9]+:[^:]*:[^:]*:/)) {
                split(substr(line, 1, RLENGTH - 1), f, ":")
                jail = f[3]
                line = substr(line, RLENGTH + 1)
            } else {
                sub(/^[0-9]+:[^:]*:/, "", line)
            }
            n = split(line, part, /[[:space:]]+/)
            name = ""
            for (i = 1; i <= n; i++) {
                tok = part[i]
                if (tok == "" || tok == "--") continue
                if (substr(tok, 1, 1) == "-") continue
                sub(/^.*\//, "", tok)
                if (tok == "firejail") continue
                name = tok
                break
            }
            if (name == "") name = (jail != "" ? jail : "shell")
            if (length(name) > 16) {
                name = substr(name, 1, 15)
                sub(/[\302-\364][\200-\277]*$/, "", name)
                name = name "~"
            }
            if (!(name in seen)) { seen[name] = ++uniq; order[uniq] = name }
            hits[name]++
            total++
        }
        END {
            if (total == 0) exit
            shown = 0
            for (i = 1; i <= uniq; i++) {
                name = order[i]
                if (++shown > max) continue
                printf "%s%s", (shown > 1 ? " " : ""), name
                if (hits[name] > 1) printf "*%d", hits[name]
            }
            if (uniq > max) printf " +%d", uniq - max
            printf "\n"
        }')
{
    printf 'SANDBOX\n'
    if [ -n "$LIST" ]; then
        printf 'Jails       %s\n' "$LIST"
    else
        printf 'Jails       none\n'
    fi
} | publish