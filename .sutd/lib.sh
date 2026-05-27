#!/bin/bash

get_cpu_usage() {
    if [ ! -f /proc/stat ]; then
        echo "0"; return
    fi
    
    local cpu user nice system idle iowait irq softirq steal
    read cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    local total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local idle1=$((idle + iowait))
    
    sleep 0.3
    
    read cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    local total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local idle2=$((idle + iowait))
    
    local totald=$((total2 - total1))
    local idled=$((idle2 - idle1))
    
    if [ "$totald" -gt 0 ]; then
        echo $(( (totald - idled) * 100 / totald ))
    else
        echo "0"
    fi
}
export -f get_cpu_usage

apply_theme() {
    local accent="${THEME_ACCENT:-208}"
    export COLOR_ACCENT="\033[38;5;${accent}m"
    export COLOR_ORANGE="$COLOR_ACCENT"
    
    if [ "${THEME_BG_ENABLED:-0}" = "1" ]; then
        export COLOR_BG="\033[48;5;${THEME_BG:-235}m"
        export COLOR_BG_RESET="\033[49m"
    else
        export COLOR_BG=""
        export COLOR_BG_RESET=""
    fi
}
export -f apply_theme

is_int() {
    [[ "$1" =~ ^-?[0-9]+$ ]]
}
export -f is_int