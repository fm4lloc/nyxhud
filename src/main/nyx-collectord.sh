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

set -e

BASE_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

# =========================================================
# XDG
# =========================================================

: "${XDG_RUNTIME_DIR:=/tmp}"

: "${XDG_CACHE_HOME:=$HOME/.cache}"

# =========================================================
# NYXHUD PATHS
# =========================================================

NYXHUD_RUNTIME_DIR="$XDG_RUNTIME_DIR/nyxhud"

NYXHUD_STATE_DIR="$NYXHUD_RUNTIME_DIR/state"

NYXHUD_RENDER_DIR="$NYXHUD_RUNTIME_DIR/render"

NYXHUD_CACHE_DIR="$XDG_CACHE_HOME/nyxhud/api"

NYXHUD_COLLECTORS_DIR="$BASE_DIR/collectors"

LOCKDIR="$NYXHUD_RUNTIME_DIR/collectord.lock"

readonly LOCKDIR

export NYXHUD_RUNTIME_DIR
export NYXHUD_STATE_DIR
export NYXHUD_RENDER_DIR
export NYXHUD_CACHE_DIR
export NYXHUD_COLLECTORS_DIR

# =========================================================
# CLEAN SESSION DATA
# =========================================================

rm -rf -- "$NYXHUD_RUNTIME_DIR"

# persistent API cache is discarded on every startup
rm -rf -- "$NYXHUD_CACHE_DIR"

# =========================================================
# DIRECTORIES
# =========================================================

mkdir -p -- "$NYXHUD_RUNTIME_DIR"

mkdir -p -- "$NYXHUD_STATE_DIR"

mkdir -p -- "$NYXHUD_RENDER_DIR"

mkdir -p -- "$NYXHUD_CACHE_DIR"

# =========================================================
# SINGLETON LOCK
# =========================================================

if ! mkdir -- "$LOCKDIR" 2>/dev/null; then

    printf '[nyxhud] collectord already running\n' >&2

    exit 1
fi

# =========================================================
# SUPERVISOR
# =========================================================

printf '[nyxhud] supervisor pid=%s\n' "$$"

# =========================================================
# CLEANUP
# =========================================================

cleanup() {

    trap - INT TERM EXIT

    printf '\n[nyxhud] stopping collectors...\n'

    rmdir "$LOCKDIR" 2>/dev/null || true

    exit 0
}

trap cleanup INT TERM EXIT

# =========================================================
# DISCOVER COLLECTORS
# =========================================================

COLLECTORS=''

for file in "$NYXHUD_COLLECTORS_DIR"/*.sh; do

    [ -f "$file" ] || continue

    name=$(basename "$file" .sh)

    interval=$(
        awk -F= '

        /^INTERVAL=/ {

            gsub(/"/, "", $2)

            gsub(/'\''/, "", $2)

            print $2

            exit
        }' "$file"
    )

    [ -n "$interval" ] || interval=3

    COLLECTORS="${COLLECTORS}
$name|$interval|$file"

    printf '[nyxhud] loaded %-12s interval=%ss\n' \
        "$name" \
        "$interval"
done

# =========================================================
# MAIN LOOP
# =========================================================

while :; do

    now=$(date +%s)

    while IFS='|' read -r name interval file; do

        [ -n "$name" ] || continue

        stamp="$NYXHUD_STATE_DIR/.${name}.time"

        last=0

        # =================================================
        # LOAD LAST EXECUTION
        # =================================================

        if [ -f "$stamp" ]; then

            read -r last < "$stamp" || last=0

            case "$last" in
               ''|*[!0-9]*) last=0 ;;
            esac
        fi

        # =================================================
        # INTERVAL CHECK
        # =================================================

        if [ $((now - last)) -lt "$interval" ]; then
            continue
        fi

        # =================================================
        # RUN COLLECTOR
        # =================================================

        if "$file" >/dev/null; then

            # =============================================
            # UPDATE TIMESTAMP
            # =============================================

            printf '%s\n' "$now" > "$stamp"

        else

            printf '[nyxhud] collector failed: %s\n' \
                "$name" >&2
        fi

    done <<EOF
$COLLECTORS
EOF

    sleep 1

done