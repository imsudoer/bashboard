#!/bin/bash

STREAK_FILE="$SUTD_DIR/data/streak.dat"
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)

if [ -f "$STREAK_FILE" ]; then
    LAST_DATE=$(awk -F= '/^last=/ {print $2}' "$STREAK_FILE")
    STREAK=$(awk -F= '/^streak=/ {print $2}' "$STREAK_FILE")
    MAX_STREAK=$(awk -F= '/^max=/ {print $2}' "$STREAK_FILE")
else
    LAST_DATE=""; STREAK=0; MAX_STREAK=0
fi

if [ "$LAST_DATE" != "$TODAY" ]; then
    if [ "$LAST_DATE" = "$YESTERDAY" ]; then
        STREAK=$((STREAK + 1))
    else
        STREAK=1
    fi
    [ "$STREAK" -gt "${MAX_STREAK:-0}" ] && MAX_STREAK=$STREAK
    cat > "$STREAK_FILE" << EOF
last=$TODAY
streak=$STREAK
max=$MAX_STREAK
EOF
fi

if [ "$STREAK" -ge 7 ]; then
    ICON="🔥"
elif [ "$STREAK" -ge 3 ]; then
    ICON="✨"
else
    ICON="·"
fi

field "Streak" "${ICON} ${STREAK} days (record: ${MAX_STREAK})"