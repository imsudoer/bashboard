#!/bin/bash

section "Security:"

LAST=$(last -n 2 -F "$USER" 2>/dev/null | awk 'NR==2 {print $4" "$5" "$6" "$7" from "$3}')
[ -n "$LAST" ] && printf "    ${COLOR_PURPLE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s${COLOR_RESET}\n" "Last login" "$LAST"

if [ -r /var/log/auth.log ]; then
    FAILED=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
    printf "    ${COLOR_PURPLE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s in auth.log${COLOR_RESET}\n" "Failed SSH" "$FAILED"
fi

if command -v fail2ban-client &>/dev/null; then
    JAILS=$(sudo -n fail2ban-client status 2>/dev/null | awk -F: '/Jail list/ {print $2}' | tr -d ' \t')
    if [ -n "$JAILS" ]; then
        TOTAL_BANNED=0
        IFS=',' read -ra JAIL_ARR <<< "$JAILS"
        for jail in "${JAIL_ARR[@]}"; do
            BANNED=$(sudo -n fail2ban-client status "$jail" 2>/dev/null | awk '/Currently banned/ {print $NF}')
            TOTAL_BANNED=$((TOTAL_BANNED + ${BANNED:-0}))
        done
        printf "    ${COLOR_PURPLE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s IPs banned${COLOR_RESET}\n" "Fail2ban" "$TOTAL_BANNED"
    fi
fi

if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo -n ufw status 2>/dev/null | awk 'NR==1 {print $2}')
    [ -n "$UFW_STATUS" ] && printf "    ${COLOR_PURPLE}▸${COLOR_RESET} %-15s ${COLOR_GRAY}%s${COLOR_RESET}\n" "Firewall" "$UFW_STATUS"
fi
