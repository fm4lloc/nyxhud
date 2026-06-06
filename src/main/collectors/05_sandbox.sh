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

INTERVAL=5

# =========================================================
# NYXHUD SANDBOX MODULE
# =========================================================

SCRIPT_NAME=$(basename "$0" .sh)

readonly SCRIPT_NAME

RENDER="$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.render"

readonly RENDER

# =========================================================
# FIREJAIL NOT INSTALLED
# =========================================================

if ! command -v firejail >/dev/null 2>&1; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
SANDBOX
Status   firejail not installed
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# FIREJAIL QUERY
# =========================================================

SANDBOX_DATA=$(
firejail --list 2>/dev/null
)

# =========================================================
# EMPTY RESULT
# =========================================================

if [ -z "$SANDBOX_DATA" ]; then

    TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

    cat > "$TMP_RENDER" <<EOF
SANDBOX
Apps     None
EOF

    mv "$TMP_RENDER" "$RENDER"

    exit 0
fi

# =========================================================
# PARSE
# =========================================================

APPS=$(
printf '%s\n' "$SANDBOX_DATA" |
awk '

/^[0-9]+:/ {

    line = $0

    sub(/^[0-9]+:[^:]*::firejail[[:space:]]*/, "", line)

    n = split(line, parts, /[[:space:]]+/)

    app = "unknown"

    for (i = 1; i <= n; i++) {

        if (parts[i] !~ /^-/) {

            app = parts[i]

            break
        }
    }

    apps[++count] = app
}

END {

    if (count == 0) {

        print "None"

        exit
    }

    for (i = 1; i <= count; i++) {

        printf "%s", apps[i]

        if (i < count)
            printf ", "
    }

    print ""
}'
)

# =========================================================
# SANITIZE
# =========================================================

APPS=${APPS:-None}

# =========================================================
# WRITE RENDER SNAPSHOT
# =========================================================

TMP_RENDER=$(mktemp "$NYXHUD_RENDER_DIR/${SCRIPT_NAME}.XXXXXX")

cat > "$TMP_RENDER" <<EOF
SANDBOX
Apps     $APPS
EOF

mv "$TMP_RENDER" "$RENDER"