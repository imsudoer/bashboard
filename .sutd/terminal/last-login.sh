#!/bin/bash

last-login() {
    local mode="all"
    local count=10
    local user=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--failed)  mode="failed"; shift ;;
            -n)           count="$2"; shift 2 ;;
            -h|--help)
                cat << 'EOF'
  last-login — SSH login history with IP and duration

  last-login                last 10 successful logins
  last-login -n 20          last 20
  last-login <user>         only specific user
  last-login -f             failed login attempts (brute-force)
  last-login -h             this help
EOF
                return
                ;;
            *) user="$1"; shift ;;
        esac
    done
    
    if [ "$mode" = "failed" ]; then
        echo -e "  \033[37mFailed SSH attempts:\033[0m"
        local logfile
        for logfile in /var/log/auth.log /var/log/secure; do
            [ -r "$logfile" ] || continue
            grep -E "Failed password|authentication failure" "$logfile" 2>/dev/null \
                | tail -n "$count" \
                | awk '{
                    date=$1" "$2" "$3
                    for(i=1;i<=NF;i++) {
                        if ($i=="from") ip=$(i+1)
                        if ($i=="user") user=$(i+1)
                        if ($i=="invalid" && $(i+1)=="user") user=$(i+2)
                    }
                    printf "    \033[31m✗\033[0m %s  user=%-15s from=%s\n", date, user, ip
                }'
            break
        done
        return
    fi
    
    echo -e "  \033[37mLast logins:\033[0m"
    
    local last_cmd="last -n $count -F"
    [ -n "$user" ] && last_cmd="$last_cmd $user"
    
    $last_cmd 2>/dev/null | head -n "$count" | while read line; do
        [ -z "$line" ] && continue
        [[ "$line" =~ ^wtmp ]] && continue
        [[ "$line" =~ ^reboot ]] && continue
        
        local u=$(echo "$line" | awk '{print $1}')
        local tty=$(echo "$line" | awk '{print $2}')
        local from=$(echo "$line" | awk '{print $3}')
        local when=$(echo "$line" | awk '{print $4" "$5" "$6" "$7}')
        local dur=$(echo "$line" | grep -oE '$[^)]+$$' | tr -d '()')
        local status=$(echo "$line" | grep -oE 'still logged in|gone - no logout' )
        
        local color="\033[32m"
        local icon="●"
        local extra=""
        
        if [ "$status" = "still logged in" ]; then
            color="\033[38;5;208m"
            extra="ACTIVE"
        elif [ "$status" = "gone - no logout" ]; then
            color="\033[33m"
            extra="crashed"
        fi
        
        printf "    ${color}${icon}\033[0m %-12s \033[90m%-19s\033[0m from %-20s \033[90m%s${extra:+ [$extra]}\033[0m\n" \
            "$u" "$when" "$from" "${dur:-?}"
    done
}

_lastlogin_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local users
    users=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd 2>/dev/null)
    COMPREPLY=( $(compgen -W "$users -f --failed -n -h" -- "$cur") )
}
complete -F _lastlogin_complete last-login