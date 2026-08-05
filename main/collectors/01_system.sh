#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

INTERVAL=3

set -u
set -f
LC_ALL=C
export LC_ALL
umask 077

NAME=${0##*/}
NAME=${NAME%.sh}
: "${NYXHUD_RENDER_DIR:?}"
: "${NYXHUD_STATE_DIR:?}"
[ -d "$NYXHUD_RENDER_DIR" ] || exit 1
[ -d "$NYXHUD_STATE_DIR" ] || exit 1

STATE="$NYXHUD_STATE_DIR/$NAME.cpu"

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

bar() {
    value=$1
    case $value in
        ''|*[!0-9]*) value=0 ;;
    esac
    [ "$value" -gt 100 ] && value=100

    filled=$((value / 10))
    out=''
    i=0
    while [ "$i" -lt 10 ]; do
        if [ "$i" -lt "$filled" ]; then
            out="$out█"
        else
            out="$out░"
        fi
        i=$((i + 1))
    done
    printf '[%s] %3d%%' "$out" "$value"
}

snapshot() {
    set +f
    awk '
        FNR == 1 && match($0, /^[0-9]+ \(.*\) /) {
            head = substr($0, 1, RLENGTH)
            rest = substr($0, RLENGTH + 1)
            pid = head + 0
            comm = head
            sub(/^[0-9]+ \(/, "", comm)
            sub(/\) $/, "", comm)
            gsub(/[ \t]/, "_", comm)
            n = split(rest, f, " ")
            if (n >= 13) print pid, comm, f[12] + f[13]
        }' /proc/[0-9]*/stat 2>/dev/null
    set -f
}

top_cpu() {
    hz=$(getconf CLK_TCK 2>/dev/null)
    case ${hz:-} in
        ''|*[!0-9]*) hz=100 ;;
    esac
    cpus=$(nproc 2>/dev/null)
    case ${cpus:-} in
        ''|*[!0-9]*|0) cpus=1 ;;
    esac

    stamp=$(awk '{ printf "%d", $1 * 100; exit }' /proc/uptime 2>/dev/null)
    case ${stamp:-} in
        ''|*[!0-9]*) return 1 ;;
    esac

    new=$(mktemp "$NYXHUD_STATE_DIR/.$NAME.XXXXXX") || return 1
    trap 'rm -f -- "$new"' EXIT INT TERM
    if ! {
        printf '# %s\n' "$stamp"
        snapshot
    } > "$new"; then
        return 1
    fi

    result=''
    if [ -r "$STATE" ]; then
        result=$(awk -v hz="$hz" -v cpus="$cpus" '
            FNR == NR {
                if ($1 == "#") { t0 = $2; next }
                prev[$1 " " $2] = $3
                next
            }
            $1 == "#" { t1 = $2; next }
            {
                key = $1 " " $2
                if (!(key in prev)) next
                d = $3 - prev[key]
                if (d > best) { best = d; name = $2 }
            }
            END {
                elapsed = (t1 - t0) / 100 * hz
                if (elapsed <= 0) exit 1
                if (best <= 0) { printf "idle"; exit 0 }
                pct = 100 * best / (elapsed * cpus)
                if (pct > 100) pct = 100
                printf "%s %.1f%%", name, pct
            }' "$STATE" "$new" 2>/dev/null)
    fi

    mv -- "$new" "$STATE"
    trap - EXIT INT TERM
    [ -n "$result" ] || return 1
    printf '%s' "$result"
}

KERNEL=$(uname -r)
HOST=$(uname -n)
CLOCK=$(date +%H:%M:%S)

LOAD=$(cut -d ' ' -f1-3 /proc/loadavg 2>/dev/null) || LOAD=''

UPTIME=$(awk '{
    s = int($1)
    d = int(s / 86400); s %= 86400
    h = int(s / 3600);  s %= 3600
    m = int(s / 60)
    if (d > 0) printf "%dd ", d
    if (h > 0) printf "%dh ", h
    printf "%dm", m
    exit
}' /proc/uptime 2>/dev/null) || UPTIME=''

MEM=$(awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    /^SwapTotal:/    { st = $2 }
    /^SwapFree:/     { sf = $2 }
    END {
        if (total <= 0) exit 1
        swap = (st > 0) ? int(((st - sf) / st) * 100) : 0
        printf "%.1fG / %.1fG|%d", (total - avail) / 1048576, total / 1048576, swap
    }' /proc/meminfo 2>/dev/null) || MEM=''

RAM=${MEM%|*}
SWAP=${MEM##*|}
case $SWAP in
    ''|*[!0-9]*) SWAP=0 ;;
esac

ROOT=$(df -P / 2>/dev/null | awk 'NR == 2 { sub(/%$/, "", $5); print $5 }')
HOMEFS=$(df -P "${HOME:-/}" 2>/dev/null | awk 'NR == 2 { sub(/%$/, "", $5); print $5 }')

TEMP=$(sensors 2>/dev/null |
       awk '/^(Tctl|Tdie|Package id 0):/ { gsub(/\+/, "", $2); print $2; exit }')

TOP=$(top_cpu) || TOP=''

{
    printf 'SYSTEM\n'
    printf 'Kernel      %s\n' "$KERNEL"
    printf 'Host        %s\n' "$HOST"
    printf 'Time        %s\n' "$CLOCK"
    printf 'Uptime      %s\n' "${UPTIME:-n/a}"
    printf 'Load        %s\n' "${LOAD:-n/a}"
    printf 'RAM         %s\n' "${RAM:-n/a}"
    printf 'Swap        %s%%\n' "$SWAP"
    printf 'Root        %s\n' "$(bar "${ROOT:-0}")"
    printf 'Home        %s\n' "$(bar "${HOMEFS:-0}")"
    printf 'CPU Temp    %s\n' "${TEMP:-n/a}"
    printf 'Top CPU     %s\n' "${TOP:-n/a}"
} | publish
