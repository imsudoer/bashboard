#!/bin/bash

# :helpme:
# title: Who Is On
# desc: Show all logged-in users with idle time, processes, and SSH origin
# category: monitoring
# usage:
#   whoison                       list all active sessions
# examples:
#   whoison
# :endhelpme:

whoison() {
    echo -e "  \033[37mUsers currently logged in:\033[0m"
    
    local count=0
    
    who -H 2>/dev/null | tail -n +2 | while read user tty when_d when_t when_z rest; do
        local from
        from=$(echo "$rest" | grep -oE '$[^)]+$' | tr -d '()')
        [ -z "$from" ] && from="local"
        
        local pids
        pids=$(ps -t "$tty" -o pid= 2>/dev/null | wc -l)
        
        local procs
        procs=$(ps -t "$tty" -o comm= 2>/dev/null | sort -u | tr '\n' ' ')
        
        local idle="?"
        if [ -e "/dev/$tty" ]; then
            local stat
            stat=$(stat -c %Y "/dev/$tty" 2>/dev/null)
            if [ -n "$stat" ]; then
                local now diff
                now=$(date +%s)
                diff=$((now - stat))
                if [ "$diff" -lt 60 ]; then
                    idle="${diff}s"
                elif [ "$diff" -lt 3600 ]; then
                    idle="$((diff / 60))m"
                else
                    idle="$((diff / 3600))h"
                fi
            fi
        fi
        
        echo ""
        printf "  \033[38;5;208m▸\033[0m \033[37m%-12s\033[0m on \033[90m%-10s\033[0m\n" "$user" "$tty"
        printf "    \033[90mfrom:\033[0m %-25s \033[90msince:\033[0m %s %s\n" "$from" "$when_d" "$when_t"
        printf "    \033[90midle:\033[0m %-10s \033[90mprocs:\033[0m %s\n" "$idle" "$pids"
        printf "    \033[90mrunning:\033[0m %s\n" "${procs:0:80}"
    done
    
    local total
    total=$(who | wc -l)
    
    echo ""
    echo -e "  \033[90mTotal: $total session(s)\033[0m"
    
    local ssh_count
    ssh_count=$(ss -tn state established '( dport = :22 or sport = :22 )' 2>/dev/null | tail -n +2 | wc -l)
    [ "$ssh_count" -gt 0 ] && echo -e "  \033[90mSSH connections: $ssh_count\033[0m"
}