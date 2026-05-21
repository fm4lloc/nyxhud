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

INTERVAL=5

# =========================================================
# NYXHUD GPU MODULE
# NVIDIA TELEMETRY
# =========================================================

SCRIPT_NAME=$(basename "$0" .sh)

readonly SCRIPT_NAME

RENDER="$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.render"

readonly RENDER

# =========================================================
# NO NVIDIA GPU
# =========================================================

if ! command -v nvidia-smi >/dev/null 2>&1; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.gpu.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
GPU
No NVIDIA GPU
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# NVIDIA-SMI QUERY
# =========================================================

GPU_DATA=$(
nvidia-smi \
--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,fan.speed,power.draw,name \
--format=csv,noheader,nounits 2>/dev/null
)

# =========================================================
# EMPTY RESULT
# =========================================================

if [ -z "$GPU_DATA" ]; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.gpu.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
GPU
Unavailable
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# PARSE
# =========================================================

OLD_IFS=$IFS

IFS='
'

set -- $(
printf '%s\n' "$GPU_DATA" |
awk -F ',' '

NR == 1 {

    temp      = $1
    util      = $2
    mem_used  = $3
    mem_total = $4
    fan       = $5
    power     = $6
    name      = $7

    gsub(/^[[:space:]]+|[[:space:]]+$/, "", temp)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", util)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", mem_used)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", mem_total)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", fan)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", power)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)

    print temp
    print util
    print mem_used
    print mem_total
    print fan
    print power
    print name
}'
)

IFS=$OLD_IFS

# =========================================================
# SANITIZE
# =========================================================

TEMP=${1:-0}

UTIL=${2:-0}

MEM_USED=${3:-0}

MEM_TOTAL=${4:-0}

FAN=${5:-0}

POWER=${6:-0}

NAME=${7:-Unknown}

# =========================================================
# WRITE RENDER SNAPSHOT
# =========================================================

TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

cat > "$TMP_RENDER" <<EOF
GPU
Model    $NAME
Temp     ${TEMP}°C
Util     ${UTIL}%
VRAM     ${MEM_USED}/${MEM_TOTAL} MB
Fan      ${FAN}%
Power    ${POWER} W
EOF

mv "$TMP_RENDER" "$RENDER"