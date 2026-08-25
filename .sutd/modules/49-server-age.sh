#!/bin/bash

AGE_FILE="$SUTD_DIR/data/install_date.dat"

if [ ! -f "$AGE_FILE" ]; then
    INSTALL_EPOCH=$(stat -c %W / 2>/dev/null)
    if [ -z "$INSTALL_EPOCH" ] || [ "$INSTALL_EPOCH" = "0" ] || [ "$INSTALL_EPOCH" = "-" ]; then
        INSTALL_EPOCH=$(stat -c %Y /lost+found 2>/dev/null || stat -c %Y /etc 2>/dev/null)
    fi
    echo "$INSTALL_EPOCH" > "$AGE_FILE"
fi

INSTALL_EPOCH=$(cat "$AGE_FILE" 2>/dev/null | tr -dc '0-9')
NOW_EPOCH=$(date +%s)
[ -z "$INSTALL_EPOCH" ] && INSTALL_EPOCH=$NOW_EPOCH
AGE_DAYS=$(( (NOW_EPOCH - INSTALL_EPOCH) / 86400 ))
[ "$AGE_DAYS" -lt 0 ] && AGE_DAYS=0
INSTALL_DATE=$(date -d "@$INSTALL_EPOCH" '+%Y-%m-%d' 2>/dev/null)

field "Born" "${INSTALL_DATE} (${AGE_DAYS} days old)"