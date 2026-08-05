#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

INTERVAL=10

set -u
set -f
LC_ALL=C
export LC_ALL
umask 077

NAME=${0##*/}
NAME=${NAME%.sh}
: "${NYXHUD_RENDER_DIR:?}"
: "${NYXHUD_CACHE_DIR:?}"
[ -d "$NYXHUD_RENDER_DIR" ] || exit 1

CACHE="$NYXHUD_CACHE_DIR/$NAME.cache"
REFRESH=${NYXHUD_MARKETS_REFRESH:-14400}
FIAT=$(printf '%s' "${NYXHUD_MARKETS_FIAT:-brl}" | tr '[:upper:]' '[:lower:]')
case $FIAT in
    [a-z][a-z][a-z]) ;;
    *) FIAT=brl ;;
esac

publish() {
    tmp=$(mktemp "$NYXHUD_RENDER_DIR/.$NAME.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT INT TERM
    if tr -d '\000-\010\013-\037\177' > "$tmp"; then
        mv -- "$tmp" "$NYXHUD_RENDER_DIR/$NAME.render"
    fi
}

if [ "${NYXHUD_MARKETS:-on}" != "on" ]; then
    exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf 'MARKETS\nMissing curl or jq\n' | publish
    exit 0
fi

NOW=$(date +%s)
STAMP=0
NEXT=0
BACKOFF=0
CACHED_FIAT=''

if [ -r "$CACHE" ]; then
    while IFS='=' read -r key value; do
        case $key in
            STAMP)   STAMP=$value ;;
            NEXT)    NEXT=$value ;;
            BACKOFF) BACKOFF=$value ;;
            FIAT)    CACHED_FIAT=$value ;;
        esac
    done < "$CACHE"
fi

if [ "$CACHED_FIAT" != "$FIAT" ]; then
    STAMP=0
    NEXT=0
    BACKOFF=0
fi
case $STAMP in ''|*[!0-9]*) STAMP=0 ;; esac
case $NEXT in ''|*[!0-9]*) NEXT=0 ;; esac
case $BACKOFF in ''|*[!0-9]*) BACKOFF=0 ;; esac

AGE=$((NOW - STAMP))
if [ "$AGE" -lt 0 ]; then
    AGE=$REFRESH
fi
if [ "$NEXT" -gt $((NOW + 3600)) ]; then
    NEXT=0
fi

if [ "$AGE" -ge "$REFRESH" ] && [ "$NOW" -ge "$NEXT" ]; then
    mkdir -p -- "$NYXHUD_CACHE_DIR" 2>/dev/null
    RAW=$(curl -fsS --proto '=https' --tlsv1.2 \
        --connect-timeout 5 --max-time 15 --retry 0 --max-filesize 65536 \
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd,$FIAT" \
        2>/dev/null)

    PARSED=''
    if [ -n "$RAW" ]; then
        PARSED=$(printf '%s' "$RAW" | jq -er --arg f "$FIAT" '
            [ .bitcoin.usd, .ethereum.usd, .solana.usd,
              .bitcoin[$f], .ethereum[$f], .solana[$f] ]
            | if any(.[]; . == null) then error("incomplete") else . end
            | @tsv' 2>/dev/null)
    fi

    tmp=$(mktemp "$NYXHUD_CACHE_DIR/.$NAME.XXXXXX") || exit 1
    if [ -n "$PARSED" ]; then
        {
            printf 'STAMP=%s\n' "$NOW"
            printf 'NEXT=0\n'
            printf 'BACKOFF=0\n'
            printf 'FIAT=%s\n' "$FIAT"
            printf '%s' "$PARSED" | awk -F '\t' '{
                printf "BTC=%.2f\nETH=%.2f\nSOL=%.2f\n", $1, $2, $3
                printf "BTC_F=%.2f\nETH_F=%.2f\nSOL_F=%.2f\n", $4, $5, $6
            }'
        } > "$tmp" && mv -- "$tmp" "$CACHE"
        STAMP=$NOW
        AGE=0
        CACHED_FIAT=$FIAT
    else
        if [ "$BACKOFF" -lt 60 ]; then
            BACKOFF=60
        else
            BACKOFF=$((BACKOFF * 2))
        fi
        [ "$BACKOFF" -gt 3600 ] && BACKOFF=3600
        if [ -r "$CACHE" ]; then
            grep -v -e '^NEXT=' -e '^BACKOFF=' "$CACHE" > "$tmp" 2>/dev/null
        fi
        printf 'NEXT=%s\nBACKOFF=%s\n' "$((NOW + BACKOFF))" "$BACKOFF" >> "$tmp"
        mv -- "$tmp" "$CACHE"
    fi
fi

if [ ! -r "$CACHE" ] || [ "$STAMP" -eq 0 ] || [ "$CACHED_FIAT" != "$FIAT" ]; then
    printf 'MARKETS\nUnavailable\n' | publish
    exit 0
fi

BTC=; ETH=; SOL=; BTC_F=; ETH_F=; SOL_F=
while IFS='=' read -r key value; do
    case $key in
        BTC) BTC=$value ;;
        ETH) ETH=$value ;;
        SOL) SOL=$value ;;
        BTC_F) BTC_F=$value ;;
        ETH_F) ETH_F=$value ;;
        SOL_F) SOL_F=$value ;;
    esac
done < "$CACHE"

for value in "$BTC" "$ETH" "$SOL" "$BTC_F" "$ETH_F" "$SOL_F"; do
    case $value in
        ''|*[!0-9.]*)
            printf 'MARKETS\nUnavailable\n' | publish
            exit 0
            ;;
    esac
done

AGE=$((AGE / 60))
SYMBOL=$(printf '%s' "$FIAT" | tr '[:lower:]' '[:upper:]')

{
    printf 'MARKETS\n'
    printf 'BTC         %s USD\n' "$BTC"
    printf 'ETH         %s USD\n' "$ETH"
    printf 'SOL         %s USD\n' "$SOL"
    printf 'BTC         %s %s\n' "$BTC_F" "$SYMBOL"
    printf 'ETH         %s %s\n' "$ETH_F" "$SYMBOL"
    printf 'SOL         %s %s\n' "$SOL_F" "$SYMBOL"
    printf 'Age         %dm\n' "$AGE"
} | publish
