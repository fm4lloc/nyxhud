#!/bin/sh

# =========================================================
# NyxHud
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2026 Fernando Magalhães
# fm4lloc@gmail.com
# nyx-eco@proton.me

# =========================================================

set -e

BASE_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

MAIN_DIR="$BASE_DIR/main"

COLLECTORD="$MAIN_DIR/nyx-collectord.sh"

RENDERER="$MAIN_DIR/nyx-renderer.py"

# =========================================================
# ALREADY RUNNING
# =========================================================

if pgrep -f nyx-collectord.sh >/dev/null ||
   pgrep -f nyx-renderer.py >/dev/null; then

    printf '[nyxhud] already running\n' >&2

    exit 1
fi

# =========================================================
# CLEANUP
# =========================================================

cleanup() {

    trap - INT TERM EXIT

    pkill -TERM -P "$$" \
        2>/dev/null || true

    exit 0
}

trap cleanup INT TERM EXIT

# =========================================================
# START COLLECTORD
# =========================================================

"$COLLECTORD" &

# =========================================================
# START RENDERER
# =========================================================

"$RENDERER" &

RENDERER_PID=$!

# =========================================================
# WAIT RENDERER
# =========================================================

wait "$RENDERER_PID"