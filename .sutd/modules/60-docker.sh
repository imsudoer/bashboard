#!/bin/bash
command -v docker &>/dev/null || exit 0

section "Docker:"

RUNNING=$(docker ps -q 2>/dev/null | wc -l)
TOTAL=$(docker ps -aq 2>/dev/null | wc -l)
IMAGES=$(docker images -q 2>/dev/null | wc -l)

printf "    ${COLOR_BLUE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s running / %s total${COLOR_RESET}\n" "Containers" "$RUNNING" "$TOTAL"
printf "    ${COLOR_BLUE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s${COLOR_RESET}\n" "Images" "$IMAGES"

if [ "$RUNNING" -gt 0 ]; then
    docker ps --format "{{.Names}}|{{.Status}}" 2>/dev/null | while IFS='|' read -r name status; do
        printf "      ${COLOR_GREEN}●${COLOR_RESET} %-13s ${COLOR_GRAY}%s${COLOR_RESET}\n" "$name" "$status"
    done
fi
