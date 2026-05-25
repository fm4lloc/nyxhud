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
# NYXHUD SYSTEM MODULE
# =========================================================

SCRIPT_NAME=$(basename "$0" .sh)

readonly SCRIPT_NAME

RENDER="$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.render"

readonly RENDER

# =========================================================
# PROGRESS BAR
# =========================================================

generate_bar() {

    value=${1%\%}

    [ -z "$value" ] && value=0

    [ "$value" -lt 0 ] 2>/dev/null && value=0

    [ "$value" -gt 100 ] 2>/dev/null && value=100

    width=10

    filled=$(( (value * width) / 100 ))

    empty=$(( width - filled ))

    bar_filled=$(printf '%*s' "$filled" '')
    bar_filled=${bar_filled// /█}

    bar_empty=$(printf '%*s' "$empty" '')
    bar_empty=${bar_empty// /░}

    printf '[%s%s] %3d%%' \
        "$bar_filled" \
        "$bar_empty" \
        "$value"
}

# =========================================================
# BASIC SYSTEM INFO
# =========================================================

KERNEL=$(uname -r)

HOST=$(uname -n)

TIME_NOW=$(date +%H:%M:%S)

USERS=$(who | awk 'END { print NR }')

LOAD=$(cut -d ' ' -f1-3 /proc/loadavg)

# =========================================================
# UPTIME
# =========================================================

UPTIME=$(
awk '{

    secs = int($1)

    days = secs / 86400
    secs %= 86400

    hours = secs / 3600
    secs %= 3600

    mins = secs / 60

    if (days > 0)
        printf "%dd ", days

    if (hours > 0)
        printf "%dh ", hours

    printf "%dm", mins

}' /proc/uptime
)

# =========================================================
# MEMORY
# =========================================================

read -r RAM_USED RAM_TOTAL SWAP <<EOF
$(awk '

/MemTotal:/ {

    mem_total = $2
}

/MemAvailable:/ {

    mem_avail = $2
}

/SwapTotal:/ {

    swap_total = $2
}

/SwapFree:/ {

    swap_free = $2
}

END {

    mem_used = mem_total - mem_avail

    ram_used_gb  = mem_used  / 1024 / 1024
    ram_total_gb = mem_total / 1024 / 1024

    if (swap_total > 0)
        swap = sprintf("%.0f%%",
            ((swap_total - swap_free) / swap_total) * 100)
    else
        swap = "0%"

    printf "%.1fG %.1fG %s\n",
        ram_used_gb,
        ram_total_gb,
        swap

}' /proc/meminfo
)
EOF

RAM_USED=${RAM_USED:-0G}

RAM_TOTAL=${RAM_TOTAL:-0G}

SWAP=${SWAP:-0%}

RAM="${RAM_USED} / ${RAM_TOTAL}"

# =========================================================
# FILESYSTEM
# =========================================================

read -r ROOT HOMEFS <<EOF
$(df -P / /home 2>/dev/null | awk '

NR == 2 {
    root = $5
}

NR == 3 {
    home = $5
}

END {

    print root, home
}')
EOF

ROOT=${ROOT:-0%}

HOMEFS=${HOMEFS:-0%}

# =========================================================
# TOP PROCESS
# =========================================================

CORES=$(nproc 2>/dev/null)

CORES=${CORES:-1}

TOP_PROCESS=$(
ps -eo comm,pcpu --sort=-pcpu 2>/dev/null |
awk -v cores="$CORES" '

NR == 2 {

    cpu = $2 / cores

    printf "%s %.1f%%", $1, cpu
}'
)

TOP_PROCESS=${TOP_PROCESS:-unknown}

# =========================================================
# CPU TEMPERATURE
# =========================================================

CPU_TEMP=$(
sensors 2>/dev/null |
awk '

/Tctl:|Package id 0:/ {

    gsub(/\+/, "", $2)

    print $2

    exit
}'
)

CPU_TEMP=${CPU_TEMP:-N/A}

# =========================================================
# WRITE RENDER SNAPSHOT
# =========================================================

TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")


cat > "$TMP_RENDER" <<EOF
SYSTEM
Kernel      $KERNEL
Host        $HOST
Time        $TIME_NOW
Uptime      $UPTIME
Users       $USERS
Load        $LOAD
RAM         $RAM
Swap        $SWAP
Root        $(generate_bar "$ROOT")
Home        $(generate_bar "$HOMEFS")
CPU Temp    $CPU_TEMP
Top Proc    $TOP_PROCESS
EOF

mv "$TMP_RENDER" "$RENDER"