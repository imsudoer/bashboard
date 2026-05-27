#!/bin/bash

source "$SUTD_DIR/lib.sh"

CPU_USAGE=$(get_cpu_usage)
field "CPU" "${CPU_USAGE}%"

if [ "$SHOW_CPU_TEMP" = "1" ]; then
    if command -v sensors &>/dev/null; then
        TEMP=$(sensors 2>/dev/null | awk '/Package id 0:|Tctl:|temp1:/ {gsub(/\+/,"",$2); print $2; exit}')
        [ -n "$TEMP" ] && field "CPU Temp" "$TEMP"
    elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        [ -n "$TEMP_RAW" ] && field "CPU Temp" "$((TEMP_RAW/1000))°C"
    fi
fi

MEM=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f%%", $3/$2*100}')
field "Memory" "${MEM} (${MEM_PCT})"

SWAP=$(free -h | awk '/^Swap:/ {if ($2 != "0B") print $3 " / " $2; else print "disabled"}')
field "Swap" "$SWAP"

DISK=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
field "Disk /" "$DISK"

DISK_INODES=$(df -i / | awk 'NR==2 {print $5}')
field "Inodes" "$DISK_INODES used on /"