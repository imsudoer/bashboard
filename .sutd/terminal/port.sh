#!/bin/bash

# :helpme:
# title: Port Checker
# desc: Check if TCP port is open on remote host
# usage:
#   port <host> <port>
# examples:
#   port google.com 443
# :endhelpme:

port() {
    local host=""
    local p=""
    local timeout=3
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -t|--timeout) timeout="$2"; shift 2 ;;
            -h|--help)
                cat << 'EOF'
  port — check if TCP port is open

  port <host> <port>             check single port
  port <host> <port> -t 5        with custom timeout
  port <host> 80,443,8080        check multiple (comma-separated)
  port -h                        this help

  Examples:
    port google.com 443
    port localhost 22
    port 1.2.3.4 80,443
EOF
                return
                ;;
            *)
                if [ -z "$host" ]; then host="$1"
                elif [ -z "$p" ]; then p="$1"; fi
                shift
                ;;
        esac
    done
    
    [ -z "$host" ] || [ -z "$p" ] && { echo "  usage: port <host> <port>"; return 1; }
    
    IFS=',' read -ra ports <<< "$p"
    
    for one in "${ports[@]}"; do
        printf "  %-25s :%-5s  " "$host" "$one"
        
        if timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$one" 2>/dev/null; then
            echo -e "\033[32m● OPEN\033[0m"
        else
            echo -e "\033[31m● CLOSED\033[0m \033[90m(or filtered/timeout)\033[0m"
        fi
    done
}

_port_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -le 2 ]; then
        COMPREPLY=( $(compgen -A hostname -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "-t --timeout -h" -- "$cur") )
    fi
}
complete -F _port_complete port