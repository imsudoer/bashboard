#!/bin/bash

source "$SUTD_DIR/lib.sh"

bar() {
    local pct=$1
    is_int "$pct" || pct=0
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100
    
    local width=20
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local color="$COLOR_GREEN"
    [ "$pct" -gt 70 ] && color="$COLOR_YELLOW"
    [ "$pct" -gt 90 ] && color="$COLOR_RED"
    
    printf "${color}"
    [ "$filled" -gt 0 ] && printf '█%.0s' $(seq 1 "$filled")
    printf "${COLOR_GRAY}"
    [ "$empty" -gt 0 ] && printf '░%.0s' $(seq 1 "$empty")
    printf "${COLOR_RESET} %3d%%" "$pct"
}

divider
section "Resources:"

CPU_PCT=$(get_cpu_usage)
MEM_PCT=$(free | awk '/^Mem:/ {if ($2>0) printf "%.0f", $3/$2*100; else print 0}')
DISK_PCT=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
SWAP_PCT=$(free | awk '/^Swap:/ {if ($2>0) printf "%.0f", $3/$2*100; else print 0}')

is_int "$CPU_PCT"  || CPU_PCT=0
is_int "$MEM_PCT"  || MEM_PCT=0
is_int "$DISK_PCT" || DISK_PCT=0
is_int "$SWAP_PCT" || SWAP_PCT=0

printf "    %-7s " "CPU"  ; bar "$CPU_PCT"  ; echo
printf "    %-7s " "RAM"  ; bar "$MEM_PCT"  ; echo
printf "    %-7s " "Disk" ; bar "$DISK_PCT" ; echo
printf "    %-7s " "Swap" ; bar "$SWAP_PCT" ; echo