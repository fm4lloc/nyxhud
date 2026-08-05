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

STATE="$NYXHUD_STATE_DIR/$NAME.state"

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

rate() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1073741824) printf "%.1f GiB/s", b / 1073741824
        else if (b >= 1048576) printf "%.1f MiB/s", b / 1048576
        else if (b >= 1024) printf "%.1f KiB/s", b / 1024
        else printf "%d B/s", b
    }'
}

uint() {
    case ${1:-} in
        ''|*[!0-9]*) return 1 ;;
    esac
    return 0
}

IFACE=''
set +f
for dir in /sys/class/net/*; do
    [ -r "$dir/uevent" ] || continue
    if grep -qx 'DEVTYPE=wireguard' "$dir/uevent" 2>/dev/null; then
        IFACE=${dir##*/}
        break
    fi
done
set -f

if [ -z "$IFACE" ]; then
    printf 'WIREGUARD\nStatus      offline\n' | publish
    exit 0
fi

read -r RX < "/sys/class/net/$IFACE/statistics/rx_bytes" 2>/dev/null || RX=0
read -r TX < "/sys/class/net/$IFACE/statistics/tx_bytes" 2>/dev/null || TX=0
uint "$RX" || RX=0
uint "$TX" || TX=0

TIME=$(awk '{ printf "%d", $1; exit }' /proc/uptime)
RX_RATE=0
TX_RATE=0

if [ -r "$STATE" ]; then
    read -r OLD_IF OLD_RX OLD_TX OLD_TIME < "$STATE" 2>/dev/null || OLD_IF=''
    if [ "${OLD_IF:-}" = "$IFACE" ] &&
       uint "${OLD_RX:-}" && uint "${OLD_TX:-}" && uint "${OLD_TIME:-}"; then
        DELTA=$((TIME - OLD_TIME))
        if [ "$DELTA" -gt 0 ] && [ "$RX" -ge "$OLD_RX" ] && [ "$TX" -ge "$OLD_TX" ]; then
            RX_RATE=$(((RX - OLD_RX) / DELTA))
            TX_RATE=$(((TX - OLD_TX) / DELTA))
        fi
    fi
fi

tmp=$(mktemp "$NYXHUD_STATE_DIR/.$NAME.XXXXXX") || exit 1
trap 'rm -f -- "$tmp"' EXIT INT TERM
if printf '%s %s %s %s\n' "$IFACE" "$RX" "$TX" "$TIME" > "$tmp"; then
    mv -- "$tmp" "$STATE"
fi

{
    printf 'WIREGUARD\n'
    printf 'Status      online\n'
    printf 'Iface       %s\n' "$IFACE"
    printf 'Down        %s\n' "$(rate "$RX_RATE")"
    printf 'Up          %s\n' "$(rate "$TX_RATE")"
} | publish
