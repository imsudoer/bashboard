#!/bin/bash

section "System status:"

if [ -f /var/lib/update-notifier/updates-available ]; then
    UPD=$(grep -oP '\d+(?= update)' /var/lib/update-notifier/updates-available | head -1)
    SEC=$(grep -oP '\d+(?= security)' /var/lib/update-notifier/updates-available | head -1)
    if [ -n "$UPD" ] && [ "$UPD" -gt 0 ]; then
        printf "    ${COLOR_YELLOW}▸${COLOR_RESET} %-15s ${COLOR_YELLOW}%s available${COLOR_RESET}" "Updates" "$UPD"
        [ -n "$SEC" ] && [ "$SEC" -gt 0 ] && printf " ${COLOR_RED}(%s security)${COLOR_RESET}" "$SEC"
        echo ""
    else
        printf "    ${COLOR_GREEN}▸${COLOR_RESET} %-15s ${COLOR_GRAY}up to date${COLOR_RESET}\n" "Updates"
    fi
fi

if [ -f /var/run/reboot-required ]; then
    printf "    ${COLOR_RED}▸${COLOR_RESET} %-15s ${COLOR_RED}required${COLOR_RESET}\n" "Reboot"
else
    printf "    ${COLOR_GREEN}▸${COLOR_RESET} %-15s ${COLOR_GRAY}not needed${COLOR_RESET}\n" "Reboot"
fi

if [ -f /var/log/journal ] || command -v journalctl &>/dev/null; then
    ERRORS=$(journalctl -p err -b --no-pager 2>/dev/null | wc -l)
    if [ "$ERRORS" -gt 1 ]; then
        printf "    ${COLOR_YELLOW}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s since boot${COLOR_RESET}\n" "Journal errors" "$ERRORS"
    fi
fi
