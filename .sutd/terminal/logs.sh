#!/bin/bash

__LOGS_MAP="$HOME/.sutd/data/logs_map.dat"
mkdir -p "$(dirname "$__LOGS_MAP")"
touch "$__LOGS_MAP"

__logs_seed() {
    [ -s "$__LOGS_MAP" ] && return
    {
        [ -d /var/log/nginx ]    && echo "nginx|/var/log/nginx/access.log /var/log/nginx/error.log"
        [ -d /var/log/apache2 ]  && echo "apache|/var/log/apache2/access.log /var/log/apache2/error.log"
        [ -f /var/log/auth.log ] && echo "auth|/var/log/auth.log"
        [ -f /var/log/syslog ]   && echo "syslog|/var/log/syslog"
        [ -f /var/log/kern.log ] && echo "kernel|/var/log/kern.log"
        [ -f /var/log/fail2ban.log ] && echo "fail2ban|/var/log/fail2ban.log"
    } > "$__LOGS_MAP"
}

logs() {
    __logs_seed
    
    local target="$1"
    
    case "$target" in
        ""|-l|--list)
            echo -e "  \033[37mAvailable log targets:\033[0m"
            while IFS='|' read -r name paths; do
                [ -z "$name" ] && continue
                printf "    \033[38;5;208m▸\033[0m %-12s \033[90m%s\033[0m\n" "$name" "$paths"
            done < "$__LOGS_MAP"
            echo ""
            echo -e "  \033[90mUsage: logs <target>  |  logs systemd <unit>  |  logs docker <name>\033[0m"
            return
            ;;
        -h|--help)
            cat << 'EOF'
  logs — universal log viewer

  logs                       list available targets
  logs <target>              tail -f known log
  logs <target> -e           only error log (if separate)
  logs systemd <unit>        journalctl -u <unit> -f
  logs docker <name|id>      docker logs -f <container>
  logs add <name> <path>     register custom log
  logs rm <name>             unregister
  logs -h                    this help
EOF
            return
            ;;
        add)
            local name="$2"; local path="$3"
            [ -z "$name" ] || [ -z "$path" ] && { echo "  usage: logs add <name> <path>"; return 1; }
            sed -i "/^${name}|/d" "$__LOGS_MAP"
            echo "${name}|${path}" >> "$__LOGS_MAP"
            echo -e "  \033[32m✓\033[0m added: $name → $path"
            return
            ;;
        rm)
            sed -i "/^${2}|/d" "$__LOGS_MAP"
            echo -e "  \033[31m✗\033[0m removed: $2"
            return
            ;;
        systemd)
            local unit="$2"
            [ -z "$unit" ] && { echo "  usage: logs systemd <unit>"; return 1; }
            echo -e "  \033[90m→\033[0m journalctl -u $unit -f"
            journalctl -u "$unit" -f --output=short-iso 2>/dev/null \
                | awk '
                    /error|ERROR|Error|fatal|FATAL|fail/  { print "\033[31m" $0 "\033[0m"; next }
                    /warn|WARN|warning/                    { print "\033[33m" $0 "\033[0m"; next }
                    /info|INFO|started|Started/            { print "\033[32m" $0 "\033[0m"; next }
                    { print }
                '
            return
            ;;
        docker)
            local container="$2"
            [ -z "$container" ] && { echo "  usage: logs docker <name>"; return 1; }
            command -v docker &>/dev/null || { echo "  docker not installed"; return 1; }
            echo -e "  \033[90m→\033[0m docker logs -f $container"
            docker logs -f "$container" 2>&1 \
                | awk '
                    /error|ERROR|Error/  { print "\033[31m" $0 "\033[0m"; next }
                    /warn|WARN/          { print "\033[33m" $0 "\033[0m"; next }
                    { print }
                '
            return
            ;;
    esac
    
    local error_only=0
    [ "$2" = "-e" ] && error_only=1
    
    local entry
    entry=$(grep "^${target}|" "$__LOGS_MAP")
    
    if [ -z "$entry" ]; then
        echo "  no such target: $target"
        echo "  list with:  logs -l"
        return 1
    fi
    
    local paths="${entry#*|}"
    local files=($paths)
    
    if [ "$error_only" -eq 1 ]; then
        files=($(printf '%s\n' "${files[@]}" | grep -i error))
        [ ${#files[@]} -eq 0 ] && { echo "  no error log for $target"; return 1; }
    fi
    
    echo -e "  \033[90m→\033[0m tail -f ${files[*]}"
    echo -e "  \033[90m   Ctrl+C to stop\033[0m"
    
    tail -n 30 -F "${files[@]}" 2>/dev/null \
        | awk '
            /==>.*<==/                                   { print "\033[38;5;208m" $0 "\033[0m"; next }
            /error|ERROR|Error|fatal|FATAL|crit|emerg/  { print "\033[31m" $0 "\033[0m"; next }
            /warn|WARN|warning/                          { print "\033[33m" $0 "\033[0m"; next }
            /info|INFO|notice|started/                   { print "\033[37m" $0 "\033[0m"; next }
            /[2-5][0-9][0-9]/                            { print $0; next }
            { print }
        '
}

_logs_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "$prev" in
        logs)
            local names
            names=$(cut -d'|' -f1 "$__LOGS_MAP" 2>/dev/null)
            COMPREPLY=( $(compgen -W "$names systemd docker add rm -l -h" -- "$cur") )
            ;;
        systemd)
            local units
            units=$(systemctl list-units --type=service --no-legend --plain 2>/dev/null | awk '{print $1}' | sed 's/\.service$//')
            COMPREPLY=( $(compgen -W "$units" -- "$cur") )
            ;;
        docker)
            command -v docker &>/dev/null && {
                local containers
                containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
                COMPREPLY=( $(compgen -W "$containers" -- "$cur") )
            }
            ;;
    esac
}
complete -F _logs_complete logs