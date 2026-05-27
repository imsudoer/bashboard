#!/bin/bash

LOG="$SUTD_DIR/data/last_commands.log"
[ -f "$LOG" ] || exit 0

COUNT="${LAST_COMMANDS_COUNT:-5}"


section "Last commands from previous session:"

tail -n "$COUNT" "$LOG" | while IFS='|' read -r ts cmd; do
    printf "    ${COLOR_GRAY}%s${COLOR_RESET} %s\n" "$ts" "$cmd"
done