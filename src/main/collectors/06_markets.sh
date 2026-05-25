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

FETCH_INTERVAL=14400

# =========================================================
# NYXHUD MARKETS MODULE
# =========================================================

SCRIPT_NAME=$(basename "$0" .sh)

readonly SCRIPT_NAME

CACHE="$NYXHUD_CACHE_DIR/${SCRIPT_NAME}.cache"

RENDER="$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.render"

readonly CACHE
readonly RENDER

TMP1=$(mktemp)

TMP2=$(mktemp)

TMP3=$(mktemp)

readonly TMP1
readonly TMP2
readonly TMP3

# =========================================================
# CLEANUP
# =========================================================

cleanup() {

    rm -f "$TMP1" "$TMP2" "$TMP3"
}

trap cleanup EXIT INT TERM

# =========================================================
# CACHE AGE
# =========================================================

NOW=$(date +%s)

LAST_UPDATE=0

if [ -f "$CACHE" ]; then

    LAST_UPDATE=$(
        stat -c %Y "$CACHE" 2>/dev/null || echo 0
    )
fi

CACHE_AGE=$((NOW - LAST_UPDATE))

# =========================================================
# FETCH REMOTE DATA
# =========================================================

if [ "$CACHE_AGE" -ge "$FETCH_INTERVAL" ]; then

    # =====================================================
    # PARALLEL FETCH
    # =====================================================

    curl -fsS \
    --connect-timeout 3 \
    --max-time 5 \
    "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd" \
    > "$TMP1" &

    PID1=$!

    curl -fsS \
    --connect-timeout 3 \
    --max-time 5 \
    "https://api.exchangerate-api.com/v4/latest/USD" \
    > "$TMP2" &

    PID2=$!

    curl -fsS \
    --connect-timeout 3 \
    --max-time 5 \
    "https://api.exchangerate-api.com/v4/latest/EUR" \
    > "$TMP3" &

    PID3=$!

    wait "$PID1" || true

    wait "$PID2" || true

    wait "$PID3" || true

    # =====================================================
    # VALID FETCH
    # =====================================================

    if [ -s "$TMP1" ] &&
       [ -s "$TMP2" ] &&
       [ -s "$TMP3" ]; then

        # =================================================
        # PARSE JSON
        # =================================================

        set -- $(
            jq -r '
            [
                .bitcoin.usd,
                .ethereum.usd,
                .solana.usd
            ]
            | map(. // 0)
            | @tsv
            ' "$TMP1" 2>/dev/null
        )

        BTC=$1
        ETH=$2
        SOL=$3

        set -- $(
            jq -r '
            .rates.BRL // 0
            ' "$TMP2" "$TMP3" 2>/dev/null
        )

        USD=$1
        EUR=$2

        # =================================================
        # SANITIZE
        # =================================================

        BTC=${BTC:-0}

        ETH=${ETH:-0}

        SOL=${SOL:-0}

        USD=${USD:-0}

        EUR=${EUR:-0}

        BTC_FMT=$(LC_ALL=C printf "%.2f" "$BTC")

        ETH_FMT=$(LC_ALL=C printf "%.2f" "$ETH")

        SOL_FMT=$(LC_ALL=C printf "%.2f" "$SOL")

        USD_FMT=$(LC_ALL=C printf "%.2f" "$USD")

        EUR_FMT=$(LC_ALL=C printf "%.2f" "$EUR")

        # =================================================
        # ATOMIC CACHE WRITE
        # =================================================

        TMP_CACHE=$(mktemp "$NYXHUD_CACHE_DIR/${SCRIPT_NAME}.XXXXXX")

        cat > "$TMP_CACHE" <<EOF
BTC=$BTC_FMT
ETH=$ETH_FMT
SOL=$SOL_FMT
USD=$USD_FMT
EUR=$EUR_FMT
EOF

        mv "$TMP_CACHE" "$CACHE"
    fi
fi

# =========================================================
# DEFAULT VALUES
# =========================================================

BTC=0

ETH=0

SOL=0

USD=0

EUR=0

# =========================================================
# LOAD CACHE
# =========================================================

if [ -f "$CACHE" ]; then

    while IFS='=' read -r key value; do

        case "$key" in

            BTC) BTC=$value ;;
            ETH) ETH=$value ;;
            SOL) SOL=$value ;;
            USD) USD=$value ;;
            EUR) EUR=$value ;;

        esac

    done < "$CACHE"

    # =====================================================
    # ATOMIC RENDER WRITE
    # =====================================================

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
MARKETS
BTC      \$$BTC
ETH      \$$ETH
SOL      \$$SOL

USD      R\$ $USD
EUR      R\$ $EUR
EOF

    mv "$TMP_RENDER" "$RENDER"

else

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
MARKETS
Unavailable
EOF

    mv "$TMP_RENDER" "$RENDER"

fi