#!/bin/bash

RECORD_FILE="$SUTD_DIR/data/uptime_record.dat"
UPTIME_SECONDS=$(awk '{print int($1)}' /proc/uptime)

if [ -f "$RECORD_FILE" ]; then
    MAX_UPTIME=$(cat "$RECORD_FILE")
else
    MAX_UPTIME=0
fi

if [ "$UPTIME_SECONDS" -gt "${MAX_UPTIME:-0}" ]; then
    MAX_UPTIME=$UPTIME_SECONDS
    echo "$MAX_UPTIME" > "$RECORD_FILE"
fi

D=$((MAX_UPTIME/86400))
H=$(((MAX_UPTIME%86400)/3600))
M=$(((MAX_UPTIME%3600)/60))

if [ $D -gt 0 ]; then REC="${D}d ${H}h"
elif [ $H -gt 0 ]; then REC="${H}h ${M}m"
else REC="${M}m"; fi

if [ "$UPTIME_SECONDS" -eq "$MAX_UPTIME" ] && [ "$UPTIME_SECONDS" -gt 86400 ]; then
    field "Uptime rec" "🏆 ${REC} ${COLOR_GREEN}(NEW!)${COLOR_RESET}"
else
    field "Uptime rec" "🏆 ${REC}"
fi