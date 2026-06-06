#!/bin/sh

# =========================================================
# NyxHud
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Fernando Magalhães
# fm4lloc@gmail.com
# nyx-eco@proton.me
#
# =========================================================

INTERVAL=3

# =========================================================
# NYXHUD NETWORK MODULE
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

    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then

        LC_ALL=C awk "BEGIN {
            printf \"%.1f GiB/s\", $bytes/1073741824
        }"

    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then

        LC_ALL=C awk "BEGIN {
            printf \"%.1f MiB/s\", $bytes/1048576
        }"

    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then

        LC_ALL=C awk "BEGIN {
            printf \"%.1f KiB/s\", $bytes/1024
        }"

    else

        printf '%d B/s' "$bytes"

    fi
}

# =========================================================
# DEFAULT ROUTE
# =========================================================

read -r IFACE GATEWAY <<EOF
$(ip route 2>/dev/null | awk '

/default/ {

    print $5, $3
    exit
}')
EOF

# =========================================================
# NO NETWORK
# =========================================================

if [ -z "$IFACE" ]; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
NETWORK
Offline
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# INTERFACE VANISHED
# =========================================================

if [ ! -d "/sys/class/net/$IFACE" ]; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
NETWORK
Interface Lost
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# CURRENT COUNTERS
# =========================================================

read -r RX_NOW \
    < "/sys/class/net/$IFACE/statistics/rx_bytes" \
    2>/dev/null || RX_NOW=0

read -r TX_NOW \
    < "/sys/class/net/$IFACE/statistics/tx_bytes" \
    2>/dev/null || TX_NOW=0

TIME_NOW=$(date +%s)

# =========================================================
# PREVIOUS STATE
# =========================================================

if [ -f "$STATE" ]; then

    read -r OLD_RX OLD_TX OLD_TIME < "$STATE"

    DELTA_TIME=$((TIME_NOW - OLD_TIME))

    if [ "$DELTA_TIME" -gt 0 ] 2>/dev/null; then

        RX_RATE=$(( (RX_NOW - OLD_RX) / DELTA_TIME ))

        TX_RATE=$(( (TX_NOW - OLD_TX) / DELTA_TIME ))

        [ "$RX_RATE" -lt 0 ] 2>/dev/null && RX_RATE=0

        [ "$TX_RATE" -lt 0 ] 2>/dev/null && TX_RATE=0

    else

        RX_RATE=0
        TX_RATE=0

    fi

else

    RX_RATE=0
    TX_RATE=0

fi

# =========================================================
# SAVE STATE
# =========================================================

printf '%s %s %s\n' \
    "$RX_NOW" \
    "$TX_NOW" \
    "$TIME_NOW" \
    > "$STATE"

# =========================================================
# FORMAT OUTPUT
# =========================================================

RX_HUMAN=$(human_rate "$RX_RATE")

TX_HUMAN=$(human_rate "$TX_RATE")

IP=$(
ip -4 addr show "$IFACE" 2>/dev/null |
awk '

/inet / {

    print $2
    exit
}' |
cut -d/ -f1
)

IP=${IP:-N/A}

GATEWAY=${GATEWAY:-N/A}

# =========================================================
# WRITE RENDER SNAPSHOT
# =========================================================

TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")


cat > "$TMP_RENDER" <<EOF
NETWORK
Iface    $IFACE
LOCAL IP $IP
GATEWAY  $GATEWAY
DOWN     $RX_HUMAN
UP       $TX_HUMAN
EOF

mv "$TMP_RENDER" "$RENDER"