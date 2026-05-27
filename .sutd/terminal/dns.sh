#!/bin/bash

dns() {
    local host=""
    local types="A AAAA MX NS TXT"
    local reverse=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -a)        types="A"; shift ;;
            -aaaa|-6)  types="AAAA"; shift ;;
            -m)        types="MX"; shift ;;
            -n)        types="NS"; shift ;;
            -t)        types="TXT"; shift ;;
            -all)      types="A AAAA MX NS TXT SOA CNAME"; shift ;;
            -r|--reverse) reverse=1; shift ;;
            -h|--help)
                cat << 'EOF'
  dns — DNS query with color

  dns <host>            A + AAAA + MX + NS + TXT
  dns -a <host>         only A
  dns -aaaa <host>      only AAAA (IPv6)
  dns -m <host>         only MX
  dns -n <host>         only NS
  dns -t <host>         only TXT
  dns -all <host>       everything including SOA, CNAME
  dns -r <ip>           reverse lookup
  dns -h                this help
EOF
                return
                ;;
            *) host="$1"; shift ;;
        esac
    done
    
    [ -z "$host" ] && { echo "  usage: dns <host>"; return 1; }
    
    local tool
    if command -v dig &>/dev/null; then tool="dig"
    elif command -v host &>/dev/null; then tool="host"
    elif command -v nslookup &>/dev/null; then tool="nslookup"
    else echo "  no dig/host/nslookup available"; return 1
    fi
    
    if [ "$reverse" -eq 1 ]; then
        echo -e "  \033[37mReverse DNS for \033[38;5;208m$host\033[0m"
        if [ "$tool" = "dig" ]; then
            dig +short -x "$host" | sed 's/^/    /'
        else
            host "$host" 2>/dev/null | sed 's/^/    /'
        fi
        return
    fi
    
    echo -e "  \033[37mDNS for \033[38;5;208m$host\033[0m"
    
    for type in $types; do
        local result
        if [ "$tool" = "dig" ]; then
            result=$(dig +short "$host" "$type" 2>/dev/null)
        else
            result=$(host -t "$type" "$host" 2>/dev/null | grep -v "no.*record" | awk '{$1=$2=""; print substr($0,3)}')
        fi
        
        if [ -n "$result" ]; then
            local color
            case "$type" in
                A)     color="\033[32m" ;;
                AAAA)  color="\033[38;5;75m" ;;
                MX)    color="\033[38;5;208m" ;;
                NS)    color="\033[38;5;141m" ;;
                TXT)   color="\033[33m" ;;
                *)     color="\033[37m" ;;
            esac
            printf "  ${color}%-6s\033[0m\n" "$type"
            echo "$result" | sed 's/^/    /' | head -10
        fi
    done
}

_dns_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "-a -aaaa -m -n -t -all -r --reverse -h" -- "$cur") )
}
complete -F _dns_complete dns