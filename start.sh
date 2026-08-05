#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

set -u
LC_ALL=C
export LC_ALL

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTORD="$BASE_DIR/main/nyx-collectord.sh"
RENDERER="$BASE_DIR/main/nyx-renderer.py"

for prog in "$COLLECTORD" "$RENDERER"; do
    [ -x "$prog" ] || {
        printf 'nyxhud: %s is missing or not executable\n' "$prog" >&2
        exit 1
    }
done

"$COLLECTORD" &
COLLECTORD_PID=$!

"$RENDERER" &
RENDERER_PID=$!

stop() {
    trap - INT TERM EXIT
    kill "$COLLECTORD_PID" "$RENDERER_PID" 2>/dev/null
    wait "$COLLECTORD_PID" 2>/dev/null
    wait "$RENDERER_PID" 2>/dev/null
    exit 0
}
trap stop INT TERM EXIT

while kill -0 "$COLLECTORD_PID" 2>/dev/null &&
      kill -0 "$RENDERER_PID" 2>/dev/null; do
    sleep 1
done

printf 'nyxhud: a component exited, shutting down\n' >&2
