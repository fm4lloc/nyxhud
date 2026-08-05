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
DEVICES=${NYXHUD_DISK_RE:-^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+|vd[a-z]+|xvd[a-z]+|md[0-9]+|dm-[0-9]+)$}

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

NOW=$(awk '{ printf "%d", $1; exit }' /proc/uptime)

NEW=$(mktemp "$NYXHUD_STATE_DIR/.$NAME.XXXXXX") || exit 1
trap 'rm -f -- "$NEW"' EXIT INT TERM
awk -v now="$NOW" -v re="$DEVICES" '
    $3 ~ re { print $3, $6, $10, $13, now }' /proc/diskstats > "$NEW" || exit 1

BODY=''
if [ -s "$NEW" ] && [ -r "$STATE" ]; then
    BODY=$(awk '
        FNR == NR { prev[$1] = $2 " " $3 " " $4 " " $5; next }
        {
            if (!($1 in prev)) next
            split(prev[$1], p, " ")
            dt = $5 - p[4]
            if (dt <= 0) next
            rd = ($2 - p[1]) * 512 / dt
            wr = ($3 - p[2]) * 512 / dt
            busy = ($4 - p[3]) / (dt * 10)
            if (rd < 0) rd = 0
            if (wr < 0) wr = 0
            if (busy < 0) busy = 0
            if (busy > 100) busy = 100
            printf "%-11s %10s %10s %3d%%\n", $1, human(rd), human(wr), busy
        }
        function human(b) {
            if (b >= 1073741824) return sprintf("%.1f GiB/s", b / 1073741824)
            if (b >= 1048576)    return sprintf("%.1f MiB/s", b / 1048576)
            if (b >= 1024)       return sprintf("%.1f KiB/s", b / 1024)
            return sprintf("%d B/s", b)
        }' "$STATE" "$NEW")
fi

if ! mv -- "$NEW" "$STATE"; then
    printf 'DISK I/O\nState write failed\n' | publish
    exit 1
fi
trap - EXIT INT TERM

{
    printf 'DISK I/O\n'
    if [ -n "$BODY" ]; then
        printf '%s\n' "$BODY"
    elif [ -s "$STATE" ]; then
        printf 'sampling...\n'
    else
        printf 'No devices\n'
    fi
} | publish
