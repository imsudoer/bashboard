#!/bin/bash

source "$SUTD_DIR/lib.sh"

HIST_FILE="$SUTD_DIR/data/cpu_history.dat"
mkdir -p "$SUTD_DIR/data"
touch "$HIST_FILE"

CPU_NOW=$(get_cpu_usage)
is_int "$CPU_NOW" || CPU_NOW=0

echo "$CPU_NOW" >> "$HIST_FILE"

TERM_W=$(tput cols 2>/dev/null || echo 80)
GRAPH_W=$(( TERM_W - 15 ))
[ "$GRAPH_W" -gt 60 ] && GRAPH_W=60
[ "$GRAPH_W" -lt 10 ] && GRAPH_W=10

grep -E '^[0-9]+$' "$HIST_FILE" | tail -n "$GRAPH_W" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"

divider
section "CPU history (last logins):"

BLOCKS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

printf "    "
while IFS= read -r val; do
    is_int "$val" || continue
    idx=$(( val * 7 / 100 ))
    [ "$idx" -gt 7 ] && idx=7
    [ "$idx" -lt 0 ] && idx=0
    
    if [ "$val" -gt 80 ]; then
        color="$COLOR_RED"
    elif [ "$val" -gt 50 ]; then
        color="$COLOR_YELLOW"
    else
        color="$COLOR_GREEN"
    fi
    printf "${color}${BLOCKS[$idx]}${COLOR_RESET}"
done < "$HIST_FILE"
printf "  ${COLOR_GRAY}now: %s%%${COLOR_RESET}\n" "$CPU_NOW"