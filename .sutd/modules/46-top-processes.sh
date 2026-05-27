#!/bin/bash

COUNT="${TOP_PROCESSES_COUNT:-3}"

section "Top processes:"

echo -e "    ${COLOR_GRAY}By CPU:${COLOR_RESET}"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu --no-headers | head -n "$COUNT" | while read pid cmd cpu mem; do
    printf "      ${COLOR_BLUE}▸${COLOR_RESET} %-20s ${COLOR_GRAY}CPU %s%% / MEM %s%%${COLOR_RESET}\n" "$cmd" "$cpu" "$mem"
done

echo -e "    ${COLOR_GRAY}By RAM:${COLOR_RESET}"
ps -eo pid,comm,%cpu,%mem --sort=-%mem --no-headers | head -n "$COUNT" | while read pid cmd cpu mem; do
    printf "      ${COLOR_PURPLE}▸${COLOR_RESET} %-20s ${COLOR_GRAY}MEM %s%% / CPU %s%%${COLOR_RESET}\n" "$cmd" "$mem" "$cpu"
done