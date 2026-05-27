#!/bin/bash

svc() {
    local list_file="$HOME/.sutd/services.list"
    
    if [ ! -f "$list_file" ]; then
        echo "no services list: $list_file"; return 1
    fi
    
    local services=()
    while IFS= read -r line; do
        [ -z "$line" ] || [[ "$line" =~ ^# ]] && continue
        services+=("$line")
    done < "$list_file"
    
    if [ ${#services[@]} -eq 0 ]; then
        echo "services list is empty"; return 1
    fi
    
    echo ""
    echo "  Service manager"
    echo "  ─────────────────────────────"
    local i=1
    for s in "${services[@]}"; do
        local state
        state=$(systemctl is-active "$s" 2>/dev/null)
        local color icon
        case "$state" in
            active)   color='\033[32m'; icon='●' ;;
            inactive) color='\033[31m'; icon='●' ;;
            failed)   color='\033[31m'; icon='✗' ;;
            *)        color='\033[90m'; icon='○' ;;
        esac
        printf "  %2d) ${color}%s${icon}\033[0m %-15s \033[90m[%s]\033[0m\n" "$i" "" "$s" "$state"
        i=$((i+1))
    done
    echo "   q) quit"
    echo ""
    
    read -p "  Select service: " choice
    [[ "$choice" =~ ^[qQ]$ ]] && return 0
    [[ ! "$choice" =~ ^[0-9]+$ ]] && return 1
    [ "$choice" -lt 1 ] || [ "$choice" -gt "${#services[@]}" ] && return 1
    
    local target="${services[$((choice-1))]}"
    
    echo ""
    echo "  Selected: $target"
    echo "  ─────────────────────────────"
    echo "   1) start"
    echo "   2) stop"
    echo "   3) restart"
    echo "   4) status"
    echo "   5) enable"
    echo "   6) disable"
    echo "   7) logs (last 30)"
    echo "   q) cancel"
    echo ""
    
    read -p "  Action: " act
    
    case "$act" in
        1) sudo systemctl start    "$target" && echo "✓ started" ;;
        2) sudo systemctl stop     "$target" && echo "✓ stopped" ;;
        3) sudo systemctl restart  "$target" && echo "✓ restarted" ;;
        4) systemctl status "$target" --no-pager ;;
        5) sudo systemctl enable   "$target" && echo "✓ enabled" ;;
        6) sudo systemctl disable  "$target" && echo "✓ disabled" ;;
        7) journalctl -u "$target" -n 30 --no-pager ;;
        *) return 0 ;;
    esac
}