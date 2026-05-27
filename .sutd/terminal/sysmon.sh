#!/bin/bash

sysmon() {
    local interval=1
    local log_file=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--interval) interval="$2"; shift 2 ;;
            --log)         log_file="$HOME/.sutd/data/sysmon-$(date +%Y%m%d).log"; shift ;;
            -h|--help)
                cat << 'EOF'
  sysmon — live system monitor

  sysmon              update every 1 second
  sysmon -i 5         update every 5 seconds
  sysmon --log        also log to ~/.sutd/data/sysmon-<date>.log
  sysmon -h           this help

  Press q or Ctrl+C to exit.
EOF
                return
                ;;
        esac
    done
    
    local prev_cpu_total=0 prev_cpu_idle=0
    local prev_net_rx=0 prev_net_tx=0
    local iface
    iface=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
    
    tput smcup
    tput civis
    
    trap 'tput cnorm; tput rmcup; stty echo; return 0' EXIT INT TERM
    
    stty -echo
    
    __sysmon_bar() {
        local pct=$1
        local width=$2
        local filled=$(( pct * width / 100 ))
        local empty=$(( width - filled ))
        local color="\033[32m"
        [ "$pct" -gt 70 ] && color="\033[33m"
        [ "$pct" -gt 90 ] && color="\033[31m"
        
        printf "${color}"
        [ "$filled" -gt 0 ] && printf '█%.0s' $(seq 1 "$filled")
        printf "\033[90m"
        [ "$empty" -gt 0 ] && printf '░%.0s' $(seq 1 "$empty")
        printf "\033[0m"
    }
    
    while true; do
        local cols rows
        cols=$(tput cols)
        rows=$(tput lines)
        
        local bar_w=$((cols - 20))
        [ "$bar_w" -gt 50 ] && bar_w=50
        [ "$bar_w" -lt 10 ] && bar_w=10
        
        tput cup 0 0
        printf "\033[38;5;208m  ┌─ sysmon ─ %s ─ refresh %ss ─\033[0m\n\n" "$(hostname)" "$interval"
        
        local cpu user nice system idle iowait
        read cpu user nice system idle iowait _ < /proc/stat
        local total=$((user + nice + system + idle + iowait))
        local cpu_pct=0
        if [ "$prev_cpu_total" -gt 0 ]; then
            local td=$((total - prev_cpu_total))
            local id=$((idle + iowait - prev_cpu_idle))
            [ "$td" -gt 0 ] && cpu_pct=$(( (td - id) * 100 / td ))
        fi
        prev_cpu_total=$total
        prev_cpu_idle=$((idle + iowait))
        
        local mem_pct mem_used mem_total
        read mem_used mem_total < <(free | awk '/^Mem:/ {print $3, $2}')
        mem_pct=$((mem_used * 100 / mem_total))
        
        local swap_used swap_total swap_pct=0
        read swap_used swap_total < <(free | awk '/^Swap:/ {print $3, $2}')
        [ "$swap_total" -gt 0 ] && swap_pct=$((swap_used * 100 / swap_total))
        
        local disk_pct
        disk_pct=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
        
        local load1
        load1=$(awk '{print $1}' /proc/loadavg)
        
        local procs
        procs=$(ps -e --no-headers | wc -l)
        
        local users
        users=$(who | wc -l)
        
        local up
        up=$(uptime -p | sed 's/up //')
        
        printf "  \033[37mCPU \033[0m %3d%% " "$cpu_pct"
        __sysmon_bar "$cpu_pct" "$bar_w"
        printf "\n"
        
        printf "  \033[37mRAM \033[0m %3d%% " "$mem_pct"
        __sysmon_bar "$mem_pct" "$bar_w"
        printf " \033[90m%s/%s MB\033[0m\n" "$((mem_used/1024))" "$((mem_total/1024))"
        
        printf "  \033[37mSwap\033[0m %3d%% " "$swap_pct"
        __sysmon_bar "$swap_pct" "$bar_w"
        printf "\n"
        
        printf "  \033[37mDisk\033[0m %3d%% " "$disk_pct"
        __sysmon_bar "$disk_pct" "$bar_w"
        printf "\n\n"
        
        local rx tx
        if [ -n "$iface" ]; then
            read rx < "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null
            read tx < "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null
            
            if [ "$prev_net_rx" -gt 0 ]; then
                local rx_d=$(( (rx - prev_net_rx) / interval / 1024 ))
                local tx_d=$(( (tx - prev_net_tx) / interval / 1024 ))
                printf "  \033[37mNet \033[0m (%s)  \033[32m↓ %d KB/s\033[0m   \033[38;5;208m↑ %d KB/s\033[0m\n" \
                    "$iface" "$rx_d" "$tx_d"
            else
                printf "  \033[37mNet \033[0m (%s)  measuring...\n" "$iface"
            fi
            prev_net_rx=$rx
            prev_net_tx=$tx
        fi
        
        printf "  \033[37mLoad\033[0m %s    \033[37mProcs\033[0m %s    \033[37mUsers\033[0m %s    \033[37mUp\033[0m %s\n\n" \
            "$load1" "$procs" "$users" "$up"
        
        printf "  \033[37mTop processes:\033[0m\n"
        ps -eo pid,pcpu,pmem,comm --sort=-%cpu --no-headers 2>/dev/null | head -5 | while read pid pcpu pmem cmd; do
            printf "    \033[90m%5s\033[0m  CPU \033[33m%5s%%\033[0m  MEM \033[38;5;141m%5s%%\033[0m  %s\n" \
                "$pid" "$pcpu" "$pmem" "$cmd"
        done
        
        tput cup $((rows - 1)) 0
        printf "\033[90m  press q to exit\033[0m"
        tput el
        
        if [ -n "$log_file" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') cpu=$cpu_pct mem=$mem_pct disk=$disk_pct load=$load1" >> "$log_file"
        fi
        
        read -rsn1 -t "$interval" key
        [[ "$key" == "q" ]] || [[ "$key" == "Q" ]] && break
    done
}