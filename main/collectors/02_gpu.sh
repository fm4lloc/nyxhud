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

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

if ! command -v nvidia-smi >/dev/null 2>&1; then
    printf 'GPU\nNo NVIDIA adapter\n' | publish
    exit 0
fi

DATA=$(nvidia-smi \
    --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,fan.speed,power.draw \
    --format=csv,noheader,nounits 2>/dev/null |
    awk -F ' *, *' 'NR == 1 {
        for (i = 1; i <= 7; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
            if ($i == "" || $i == "[N/A]" || $i == "[Not Supported]") $i = "n/a"
        }
        printf "%s|%s|%s|%s|%s|%s|%s", $1, $2, $3, $4, $5, $6, $7
    }')

if [ -z "$DATA" ]; then
    printf 'GPU\nUnavailable\n' | publish
    exit 0
fi

MODEL=${DATA%%|*};    DATA=${DATA#*|}
TEMP=${DATA%%|*};     DATA=${DATA#*|}
UTIL=${DATA%%|*};     DATA=${DATA#*|}
VRAM_USED=${DATA%%|*}; DATA=${DATA#*|}
VRAM_TOTAL=${DATA%%|*}; DATA=${DATA#*|}
FAN=${DATA%%|*};      POWER=${DATA#*|}

{
    printf 'GPU\n'
    printf 'Model       %s\n' "$MODEL"
    printf 'Temp        %s C\n' "$TEMP"
    printf 'Util        %s%%\n' "$UTIL"
    printf 'VRAM        %s / %s MiB\n' "$VRAM_USED" "$VRAM_TOTAL"
    printf 'Fan         %s%%\n' "$FAN"
    printf 'Power       %s W\n' "$POWER"
} | publish
