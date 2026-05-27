#!/bin/bash

__CFG_FILE="$HOME/.sutd/data/cfgs.dat"
mkdir -p "$(dirname "$__CFG_FILE")"
touch "$__CFG_FILE"

__cfg_seed() {
    [ -s "$__CFG_FILE" ] && return
    {
        [ -f /etc/nginx/nginx.conf ]    && echo "nginx|/etc/nginx/nginx.conf"
        [ -f /etc/ssh/sshd_config ]     && echo "sshd|/etc/ssh/sshd_config"
        [ -f "$HOME/.ssh/config" ]      && echo "ssh|$HOME/.ssh/config"
        [ -f "$HOME/.bashrc" ]          && echo "bashrc|$HOME/.bashrc"
        [ -f /etc/hosts ]               && echo "hosts|/etc/hosts"
        [ -f /etc/crontab ]             && echo "crontab|/etc/crontab"
        [ -f "$HOME/.sutd/info.conf" ]  && echo "sutd|$HOME/.sutd/info.conf"
    } > "$__CFG_FILE"
}

cfg() {
    __cfg_seed
    
    if [ $# -eq 0 ]; then
        if [ ! -s "$__CFG_FILE" ]; then
            echo "  no configs registered"
            echo "  add with:  cfg add <name> <path>"
            return
        fi
        echo -e "  \033[37mRegistered configs:\033[0m"
        local i=1
        while IFS='|' read -r name path; do
            [ -z "$name" ] && continue
            local status="\033[32m●\033[0m"
            [ ! -f "$path" ] && status="\033[31m✗\033[0m"
            printf "  \033[90m%2d)\033[0m %s \033[38;5;208m%-15s\033[0m \033[90m%s\033[0m\n" "$i" "$status" "$name" "$path"
            i=$((i+1))
        done < "$__CFG_FILE"
        return
    fi
    
    case "$1" in
        add)
            local name="$2"; local path="$3"
            [ -z "$name" ] || [ -z "$path" ] && { echo "  usage: cfg add <name> <path>"; return 1; }
            sed -i "/^${name}|/d" "$__CFG_FILE"
            echo "${name}|${path}" >> "$__CFG_FILE"
            echo -e "  \033[32m✓\033[0m added: $name → $path"
            ;;
        rm|remove)
            sed -i "/^${2}|/d" "$__CFG_FILE"
            echo -e "  \033[31m✗\033[0m removed: $2"
            ;;
        backup)
            local entry path
            entry=$(grep "^${2}|" "$__CFG_FILE")
            [ -z "$entry" ] && { echo "  no such config: $2"; return 1; }
            path="${entry#*|}"
            local bak="${path}.bak.$(date +%Y%m%d-%H%M%S)"
            sudo cp "$path" "$bak" 2>/dev/null || cp "$path" "$bak"
            echo -e "  \033[32m✓\033[0m backed up → $bak"
            ;;
        -h|--help)
            cat << 'EOF'
  cfg — quick config editor

  cfg                          list registered configs
  cfg <name>                   edit config
  cfg add <name> <path>        register new
  cfg rm <name>                unregister
  cfg backup <name>            create timestamped backup
EOF
            ;;
        *)
            local entry path
            entry=$(grep "^${1}|" "$__CFG_FILE")
            [ -z "$entry" ] && { echo "  no such config: $1"; echo "  list:  cfg"; return 1; }
            path="${entry#*|}"
            [ ! -f "$path" ] && { echo "  file not found: $path"; return 1; }
            
            if [ -w "$path" ]; then
                ${EDITOR:-nano} "$path"
            else
                sudo ${EDITOR:-nano} "$path"
            fi
            ;;
    esac
}

_cfg_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [ "$prev" = "cfg" ]; then
        local names
        names=$(cut -d'|' -f1 "$__CFG_FILE" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$names add rm backup" -- "$cur") )
    fi
}
complete -F _cfg_complete cfg