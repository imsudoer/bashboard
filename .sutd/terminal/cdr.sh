#!/bin/bash

__CDR_FILE="$HOME/.sutd/data/cdr_history.dat"
__CDR_LIMIT=30
mkdir -p "$(dirname "$__CDR_FILE")"
touch "$__CDR_FILE"

__cdr_track() {
    local cur="$PWD"
    [ "$cur" = "$HOME" ] && return
    [ "$cur" = "/" ] && return
    
    sed -i "\|^${cur}$|d" "$__CDR_FILE" 2>/dev/null
    echo "$cur" >> "$__CDR_FILE"
    
    tail -n "$__CDR_LIMIT" "$__CDR_FILE" > "${__CDR_FILE}.tmp" && \
        mv "${__CDR_FILE}.tmp" "$__CDR_FILE"
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__cdr_track"
else
    case ";$PROMPT_COMMAND;" in
        *";__cdr_track;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;__cdr_track" ;;
    esac
fi

cdr() {
    local arg="$1"
    
    case "$arg" in
        -h|--help)
            cat << 'EOF'
  cdr — recent-directories navigator

  cdr                     interactive picker (last 20)
  cdr <n>                 jump to entry #n
  cdr -c                  clear history
  cdr -h                  this help

  Companion: cdd <pattern>  fuzzy-match cd
EOF
            return
            ;;
        -c|--clear)
            > "$__CDR_FILE"
            echo -e "  \033[31m✗\033[0m history cleared"
            return
            ;;
    esac
    
    if [ ! -s "$__CDR_FILE" ]; then
        echo "  (no recent directories)"
        return
    fi
    
    local dirs=()
    while IFS= read -r line; do
        dirs+=("$line")
    done < <(tac "$__CDR_FILE" | head -20)
    
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        local idx=$((arg - 1))
        if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#dirs[@]}" ]; then
            echo "  invalid index: $arg"
            return 1
        fi
        local target="${dirs[$idx]}"
        [ ! -d "$target" ] && { echo "  no longer exists: $target"; return 1; }
        cd "$target"
        return
    fi
    
    echo -e "  \033[37mRecent directories:\033[0m"
    local i=1
    for d in "${dirs[@]}"; do
        local marker="  "
        [ "$d" = "$PWD" ] && marker="\033[38;5;208m●\033[0m "
        printf "  %2d) %b\033[90m%s\033[0m\n" "$i" "$marker" "$d"
        i=$((i+1))
    done
    echo ""
    read -p "  Select [q to cancel]: " choice
    
    [[ "$choice" =~ ^[qQ]$ ]] || [ -z "$choice" ] && return
    [[ ! "$choice" =~ ^[0-9]+$ ]] && { echo "  invalid"; return 1; }
    
    local target="${dirs[$((choice-1))]}"
    [ -z "$target" ] && { echo "  invalid"; return 1; }
    [ ! -d "$target" ] && { echo "  no longer exists: $target"; return 1; }
    cd "$target"
}

cdd() {
    local pattern="$1"
    [ -z "$pattern" ] && { echo "  usage: cdd <pattern>"; return 1; }
    
    local match
    match=$(tac "$__CDR_FILE" | grep -i "$pattern" | head -1)
    
    if [ -z "$match" ]; then
        echo "  no recent dir matches '$pattern'"
        return 1
    fi
    
    [ ! -d "$match" ] && { echo "  no longer exists: $match"; return 1; }
    
    echo -e "  \033[90m→\033[0m $match"
    cd "$match"
}

_cdd_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local words
    words=$(awk -F/ '{for (i=2;i<=NF;i++) print $i}' "$__CDR_FILE" 2>/dev/null | sort -u)
    COMPREPLY=( $(compgen -W "$words" -- "$cur") )
}
complete -F _cdd_complete cdd