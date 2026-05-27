#!/bin/bash
[ -f "$SUTD_DIR/services.list" ] || exit 0

section "Services:"

while IFS= read -r svc; do
    [ -z "$svc" ] || [[ "$svc" =~ ^# ]] && continue
    if systemctl list-unit-files "${svc}.service" &>/dev/null && \
       systemctl cat "${svc}.service" &>/dev/null; then
        STATE=$(systemctl is-active "$svc" 2>/dev/null)
        if [ "$STATE" = "active" ]; then
            SINCE=$(systemctl show "$svc" --property=ActiveEnterTimestamp --value 2>/dev/null)
            if [ -n "$SINCE" ] && [ "$SINCE" != "n/a" ]; then
                SINCE_EPOCH=$(date -d "$SINCE" +%s 2>/dev/null)
                NOW_EPOCH=$(date +%s)
                DIFF=$((NOW_EPOCH - SINCE_EPOCH))
                D=$((DIFF/86400)); H=$(((DIFF%86400)/3600)); M=$(((DIFF%3600)/60))
                if [ $D -gt 0 ]; then DUR="${D}d ${H}h"
                elif [ $H -gt 0 ]; then DUR="${H}h ${M}m"
                else DUR="${M}m"; fi
                printf "    ${COLOR_GREEN}●${COLOR_RESET} %-15s ${COLOR_GRAY}up %s${COLOR_RESET}\n" "$svc" "$DUR"
            else
                printf "    ${COLOR_GREEN}●${COLOR_RESET} %-15s ${COLOR_GRAY}active${COLOR_RESET}\n" "$svc"
            fi
        elif [ "$STATE" = "inactive" ] || [ "$STATE" = "failed" ]; then
            SINCE=$(systemctl show "$svc" --property=InactiveEnterTimestamp --value 2>/dev/null)
            if [ -n "$SINCE" ] && [ "$SINCE" != "n/a" ]; then
                printf "    ${COLOR_RED}●${COLOR_RESET} %-15s ${COLOR_GRAY}down since %s${COLOR_RESET}\n" "$svc" "$(date -d "$SINCE" '+%Y-%m-%d %H:%M' 2>/dev/null)"
            else
                printf "    ${COLOR_RED}●${COLOR_RESET} %-15s ${COLOR_GRAY}${STATE}${COLOR_RESET}\n" "$svc"
            fi
        else
            printf "    ${COLOR_YELLOW}●${COLOR_RESET} %-15s ${COLOR_GRAY}${STATE}${COLOR_RESET}\n" "$svc"
        fi
    else
        printf "    ${COLOR_GRAY}○ %-15s not installed${COLOR_RESET}\n" "$svc"
    fi
done < "$SUTD_DIR/services.list"
