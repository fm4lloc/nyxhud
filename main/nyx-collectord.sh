#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Fernando Magalhães <fm4lloc@gmail.com>

set -u
set -f
LC_ALL=C
export LC_ALL
umask 077

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTORS_DIR="$BASE_DIR/collectors"
TIMEOUT=${NYXHUD_TIMEOUT:-10}
case $TIMEOUT in
    ''|*[!0-9]*|0) TIMEOUT=10 ;;
esac
TAB=$(printf '\t')

die() {
    printf 'nyx-collectord: %s\n' "$1" >&2
    exit 1
}

secure_dir() {
    [ -L "$1" ] && die "$1 is a symbolic link"
    if ! mkdir -- "$1" 2>/dev/null; then
        if [ ! -d "$1" ]; then
            parent=${1%/*}
            [ -n "$parent" ] && [ "$parent" != "$1" ] &&
                mkdir -p -- "$parent" 2>/dev/null
            mkdir -- "$1" 2>/dev/null || die "cannot create $1"
        fi
    fi
    chmod 700 -- "$1" 2>/dev/null || die "cannot secure $1"
}

if [ -n "${NYXHUD_RUNTIME_DIR:-}" ]; then
    case $NYXHUD_RUNTIME_DIR in
        /*) ;;
        *) die 'NYXHUD_RUNTIME_DIR must be an absolute path' ;;
    esac
    RUNTIME_DIR=$NYXHUD_RUNTIME_DIR
elif [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR/nyxhud"
else
    die 'XDG_RUNTIME_DIR is unset; set NYXHUD_RUNTIME_DIR to a private directory'
fi

if [ -n "${NYXHUD_CACHE_DIR:-}" ]; then
    case $NYXHUD_CACHE_DIR in
        /*) ;;
        *) die 'NYXHUD_CACHE_DIR must be an absolute path' ;;
    esac
    CACHE_DIR=$NYXHUD_CACHE_DIR
elif [ -n "${XDG_CACHE_HOME:-}" ]; then
    CACHE_DIR="$XDG_CACHE_HOME/nyxhud"
elif [ -n "${HOME:-}" ]; then
    CACHE_DIR="$HOME/.cache/nyxhud"
else
    die 'neither XDG_CACHE_HOME nor HOME is set'
fi

RENDER_DIR="$RUNTIME_DIR/render"
STATE_DIR="$RUNTIME_DIR/state"
LOCK_DIR="$RUNTIME_DIR/collectord.lock"

secure_dir "$RUNTIME_DIR"
secure_dir "$RENDER_DIR"
secure_dir "$STATE_DIR"
secure_dir "$CACHE_DIR"

if ! mkdir -- "$LOCK_DIR" 2>/dev/null; then
    owner=''
    [ -r "$LOCK_DIR/pid" ] && read -r owner < "$LOCK_DIR/pid"
    case ${owner:-} in
        ''|*[!0-9]*) owner='' ;;
    esac
    if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
        die "already running (pid $owner)"
    fi
    printf 'nyx-collectord: taking over stale lock\n' >&2
    rm -f -- "$LOCK_DIR/pid"
    rmdir -- "$LOCK_DIR" 2>/dev/null
    mkdir -- "$LOCK_DIR" 2>/dev/null || die 'lost the race for the stale lock'
fi
printf '%s\n' "$$" > "$LOCK_DIR/pid"
read -r holder < "$LOCK_DIR/pid" 2>/dev/null || holder=''
[ "$holder" = "$$" ] || die 'lost the lock to another instance'

cleanup() {
    trap - INT TERM EXIT
    rm -f -- "$LOCK_DIR/pid"
    rmdir -- "$LOCK_DIR" 2>/dev/null
    exit 0
}
trap cleanup INT TERM EXIT

set +f
rm -f -- "$RENDER_DIR"/* "$RENDER_DIR"/.[!.]* 2>/dev/null
rm -f -- "$STATE_DIR"/* "$STATE_DIR"/.[!.]* 2>/dev/null
set -f

export NYXHUD_RUNTIME_DIR="$RUNTIME_DIR"
export NYXHUD_RENDER_DIR="$RENDER_DIR"
export NYXHUD_STATE_DIR="$STATE_DIR"
export NYXHUD_CACHE_DIR="$CACHE_DIR"

RUNNER=''
if command -v timeout >/dev/null 2>&1; then
    RUNNER="timeout -k 2 $TIMEOUT"
else
    printf 'nyx-collectord: timeout(1) not found, collectors run unbounded\n' >&2
fi

LISTING=''
SCHEDULE=''

scan() {
    set +f
    LISTING=''
    for path in "$COLLECTORS_DIR"/[0-9][0-9]_*.sh; do
        [ -f "$path" ] || continue
        if [ -x "$path" ]; then
            LISTING="$LISTING$path:x$TAB"
        else
            LISTING="$LISTING$path:-$TAB"
        fi
    done
    set -f
}

discover() {
    SCHEDULE=''
    NAMES=' '
    set +f
    for path in "$COLLECTORS_DIR"/[0-9][0-9]_*.sh; do
        [ -f "$path" ] || continue

        name=${path##*/}
        name=${name%.sh}

        if [ ! -x "$path" ]; then
            printf 'nyx-collectord: %-14s disabled (not executable)\n' "$name" >&2
            continue
        fi

        interval=$(awk -F= '
            /^INTERVAL=/ { gsub(/[^0-9]/, "", $2); print $2; exit }' "$path")
        case ${interval:-} in
            ''|*[!0-9]*|0) interval=5 ;;
        esac

        SCHEDULE="$SCHEDULE$name$TAB$interval$TAB$path$TAB-1
"
        NAMES="$NAMES$name "
        printf 'nyx-collectord: %-14s every %ss\n' "$name" "$interval"
    done

    for block in "$RENDER_DIR"/*.render; do
        [ -f "$block" ] || continue
        base=${block##*/}
        base=${base%.render}
        case $NAMES in
            *" $base "*) ;;
            *) rm -f -- "$block" ;;
        esac
    done
    set -f
}

scan
discover

[ -n "$SCHEDULE" ] || die "no collectors found in $COLLECTORS_DIR"

printf 'nyx-collectord: running (pid %s)\n' "$$"

while :; do
    previous=$LISTING
    scan
    if [ "$LISTING" != "$previous" ]; then
        printf 'nyx-collectord: collectors directory changed, rescanning\n' >&2
        discover
    fi

    now=$(awk '{ printf "%d", $1; exit }' /proc/uptime)
    wake=$((now + 60))
    UPDATED=''

    while IFS="$TAB" read -r name interval path due; do
        [ -n "$name" ] || continue

        if [ "$due" -le "$now" ]; then
            if $RUNNER "$path" >/dev/null </dev/null; then
                :
            else
                printf 'nyx-collectord: %s failed (%s)\n' "$name" "$?" >&2
            fi
            due=$((now + interval))
        fi

        [ "$due" -lt "$wake" ] && wake=$due
        UPDATED="$UPDATED$name$TAB$interval$TAB$path$TAB$due
"
    done <<EOF
$SCHEDULE
EOF

    SCHEDULE=$UPDATED

    set +f
    rm -f -- "$RENDER_DIR"/.[!.]* "$STATE_DIR"/.[!.]* 2>/dev/null
    set -f

    delay=$((wake - $(awk '{ printf "%d", $1; exit }' /proc/uptime)))
    [ "$delay" -lt 1 ] && delay=1
    sleep "$delay"
done
