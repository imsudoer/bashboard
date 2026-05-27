#!/bin/bash

__AL_FILE="$HOME/.sutd/data/aliases.dat"
mkdir -p "$(dirname "$__AL_FILE")"
touch "$__AL_FILE"

al() {
    local file="$__AL_FILE"
    
    if [ $# -eq 0 ]; then
        if [ ! -s "$file" ]; then
            echo "  (no aliases yet) — usage: al \"command\" name"
            return
        fi
        echo ""
        echo -e "  \033[37mSaved aliases:\033[0m"
        local i=1
        while IFS='|' read -r name cmd; do
            [ -z "$name" ] && continue
            printf "  \033[90m%2d)\033[0m \033[38;5;208m%-15s\033[0m \033[90m→\033[0m %s\n" "$i" "$name" "$cmd"
            i=$((i+1))
        done < "$file"
        echo ""
        return
    fi
    
    case "$1" in
        -s|--search)
            grep -i --color=auto "$2" "$file" | column -t -s'|' 2>/dev/null
            return
            ;;
        -h|--help)
            cat << 'EOF'
  al — alias manager

  Usage:
    al                              list all
    al "<command>" <name>           save alias
    al <name>                       execute alias
    al <name> arg1 arg2             execute with positional args ({1}, {2}...)
    al <name> -e                    edit alias
    al <name> -d                    delete alias
    al <name> --info                show command without executing
    al -s <pattern>                 search
    al -e                           edit aliases file in $EDITOR
    al -h                           this help

  Templating:
    al "systemctl {1} {2}" sysctl
    sysctl restart nginx            → systemctl restart nginx
EOF
            return
            ;;
        -e|--edit-file)
            ${EDITOR:-nano} "$file"
            return
            ;;
    esac
    
    if [ $# -ge 2 ] && [[ "$1" == *" "* || "$1" == *[a-zA-Z]* && "$2" != -* ]] && \
       ! grep -q "^${2}|" "$file" 2>/dev/null && [[ "$2" =~ ^[a-zA-Z0-9_-]+$ ]] && \
       [[ "$1" =~ [[:space:]] || "$1" == *=* || "$1" == *\;* || "$1" == *\|* ]]; then
        sed -i "/^${2}|/d" "$file"
        echo "${2}|${1}" >> "$file"
        echo -e "  \033[32m✓\033[0m saved: \033[38;5;208m${2}\033[0m → ${1}"
        return
    fi
    
    local name="$1"; shift
    local entry
    entry=$(grep "^${name}|" "$file" | head -1)
    
    if [ -z "$entry" ]; then
        echo -e "  \033[31m✗\033[0m no such alias: ${name}"
        echo -e "  \033[90mtip: to save use →  al \"<command>\" ${name}\033[0m"
        return 1
    fi
    
    local cmd="${entry#*|}"
    
    case "$1" in
        -d|--delete)
            sed -i "/^${name}|/d" "$file"
            echo -e "  \033[31m✗\033[0m deleted: ${name}"
            return
            ;;
        -e|--edit)
            read -e -i "$cmd" -p "  edit [${name}]: " new
            [ -z "$new" ] && return
            sed -i "/^${name}|/d" "$file"
            echo "${name}|${new}" >> "$file"
            echo -e "  \033[32m✓\033[0m updated"
            return
            ;;
        --info)
            echo -e "  \033[38;5;208m${name}\033[0m → ${cmd}"
            return
            ;;
    esac
    
    local i=1
    for arg in "$@"; do
        cmd=$(echo "$cmd" | sed "s|{${i}}|${arg}|g")
        i=$((i+1))
    done
    
    echo -e "  \033[90m→\033[0m ${cmd}"
    eval "$cmd"
}

_al_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [ "$COMP_CWORD" -eq 1 ]; then
        local names
        names=$(cut -d'|' -f1 "$__AL_FILE" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$names -s -e -h" -- "$cur") )
    fi
}
complete -F _al_complete al