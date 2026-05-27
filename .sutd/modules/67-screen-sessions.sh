#!/bin/bash

has_screen=0
has_tmux=0

command -v screen &>/dev/null && has_screen=1
command -v tmux &>/dev/null && has_tmux=1

[ "$has_screen" = "0" ] && [ "$has_tmux" = "0" ] && exit 0

screen_count=0
tmux_count=0

if [ "$has_screen" = "1" ]; then
    screen_count=$(screen -ls 2>/dev/null | grep -cE '^\s+[0-9]+\.')
fi

if [ "$has_tmux" = "1" ]; then
    tmux_count=$(tmux ls 2>/dev/null | wc -l)
fi

total=$((screen_count + tmux_count))
[ "$total" -eq 0 ] && exit 0

divider
section "Background sessions:"

if [ "$screen_count" -gt 0 ]; then
    echo -e "    ${COLOR_GRAY}screen:${COLOR_RESET}"
    
    screen -ls 2>/dev/null | grep -E '^\s+[0-9]+\.' | while read line; do
        name=$(echo "$line" | awk '{print $1}')
        state=$(echo "$line" | grep -oE '$[^)]+$$' | tr -d '()')
        date_str=$(echo "$line" | grep -oE '$[^)]+$' | head -1 | tr -d '()')
        
        case "$state" in
            *Attached*) color="$COLOR_GREEN"; icon="●" ;;
            *Detached*) color="$COLOR_YELLOW"; icon="○" ;;
            *Dead*)     color="$COLOR_RED"; icon="✗" ;;
            *)          color="$COLOR_GRAY"; icon="·" ;;
        esac
        
        printf "      ${color}${icon}${COLOR_RESET} %-30s ${COLOR_GRAY}%-10s %s${COLOR_RESET}\n" \
            "$name" "$state" "$date_str"
    done
fi

if [ "$tmux_count" -gt 0 ]; then
    echo -e "    ${COLOR_GRAY}tmux:${COLOR_RESET}"
    
    tmux ls 2>/dev/null | while IFS=: read -r name rest; do
        windows=$(echo "$rest" | grep -oE '[0-9]+ windows?' | head -1)
        created=$(echo "$rest" | grep -oE 'created [^)]+' | sed 's/created //')
        attached=""
        echo "$rest" | grep -q "attached" && attached=" attached"
        
        if [ -n "$attached" ]; then
            color="$COLOR_GREEN"; icon="●"
        else
            color="$COLOR_YELLOW"; icon="○"
        fi
        
        info="${windows}${attached}"
        printf "      ${color}${icon}${COLOR_RESET} %-30s ${COLOR_GRAY}%-20s %s${COLOR_RESET}\n" \
            "$name" "$info" "$created"
    done
fi

echo -e "    ${COLOR_GRAY}── ${screen_count} screen, ${tmux_count} tmux${COLOR_RESET}"