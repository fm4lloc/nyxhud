#!/bin/sh

# =========================================================
# NyxHud
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Fernando Magalhães
# fm4lloc@gmail.com
# nyx-eco@proton.me
#
# Technical collaboration: Nyx
# =========================================================

INTERVAL=3

# =========================================================
# NYXHUD DISK IO MODULE
# =========================================================

SCRIPT_NAME=$(basename "$0" .sh)

readonly SCRIPT_NAME

STATE="$NYXHUD_STATE_DIR/${SCRIPT_NAME}.state"

RENDER="$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.render"

readonly STATE
readonly RENDER

# =========================================================
# HUMAN RATE
# =========================================================

human_rate() {

    bytes=$1

    LC_ALL=C

    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then

        awk "BEGIN {
            printf \"%.1f GiB/s\", $bytes/1073741824
        }"

    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then

        awk "BEGIN {
            printf \"%.1f MiB/s\", $bytes/1048576
        }"

    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then

        awk "BEGIN {
            printf \"%.1f KiB/s\", $bytes/1024
        }"

    else

        printf '%d B/s' "$bytes"

    fi
}

# =========================================================
# CURRENT TIME
# =========================================================

TIME_NOW=$(date +%s)

# =========================================================
# LOAD PREVIOUS STATE
# =========================================================

OLD_STATE=$(mktemp)

if [ -f "$STATE" ]; then

    cp "$STATE" "$OLD_STATE" 2>/dev/null || true
fi

# =========================================================
# WRITE NEW STATE
# =========================================================

NEW_STATE=$(mktemp)

awk -v now="$TIME_NOW" '

$3 ~ /^(sd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$/ {

    device = $3
    read_sectors = $6
    write_sectors = $10
    io_ms = $13

    printf "%s %s %s %s %s\n",
        device,
        read_sectors,
        write_sectors,
        io_ms,
        now
}
' /proc/diskstats > "$NEW_STATE"

mv "$NEW_STATE" "$STATE"

# =========================================================
# WRITE RENDER SNAPSHOT
# =========================================================

TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

{
    printf 'DISKIO\n'

    while read -r DEV READ_NOW WRITE_NOW IO_NOW TS_NOW; do

        OLD_LINE=$(
            awk -v dev="$DEV" '

            $1 == dev {

                print
                exit
            }
            ' "$OLD_STATE"
        )

        if [ -n "$OLD_LINE" ]; then

            set -- $OLD_LINE

            OLD_READ=$2
            OLD_WRITE=$3
            OLD_IO=$4
            OLD_TS=$5

            DELTA_TIME=$((TS_NOW - OLD_TS))

            if [ "$DELTA_TIME" -le 0 ] 2>/dev/null; then

                DELTA_TIME=1
            fi

            READ_BYTES=$(( 
                ((READ_NOW - OLD_READ) * 512) / DELTA_TIME
            ))

            WRITE_BYTES=$(( 
                ((WRITE_NOW - OLD_WRITE) * 512) / DELTA_TIME
            ))

            BUSY=$(( 
                (IO_NOW - OLD_IO) / (DELTA_TIME * 10)
            ))

            [ "$READ_BYTES" -lt 0 ] 2>/dev/null && READ_BYTES=0

            [ "$WRITE_BYTES" -lt 0 ] 2>/dev/null && WRITE_BYTES=0

            [ "$BUSY" -lt 0 ] 2>/dev/null && BUSY=0

        else

            READ_BYTES=0
            WRITE_BYTES=0
            BUSY=0

        fi

        READ_HUMAN=$(human_rate "$READ_BYTES")

        WRITE_HUMAN=$(human_rate "$WRITE_BYTES")

        printf '%-8s R %-9s W %-9s B %s%%\n' \
            "$DEV" \
            "$READ_HUMAN" \
            "$WRITE_HUMAN" \
            "$BUSY"

    done < "$STATE"

} > "$TMP_RENDER"

mv "$TMP_RENDER" "$RENDER"

rm -f "$OLD_STATE"