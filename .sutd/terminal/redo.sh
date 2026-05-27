#!/bin/bash

redo() {
    local last
    last=$(fc -ln -2 2>/dev/null | head -1 | sed 's/^[[:space:]]*//')
    
    [ -z "$last" ] && { echo "  no previous command"; return 1; }
    [ "${last}" = "redo" ] || [[ "${last}" == redo\ * ]] && {
        last=$(fc -ln -3 2>/dev/null | head -1 | sed 's/^[[:space:]]*//')
    }
    
    if [ $# -eq 0 ]; then
        echo -e "  \033[90m→\033[0m $last"
        eval "$last"
        return
    fi
    
    if [[ "$1" == s/* ]]; then
        local pattern="$1"
        local new_cmd
        new_cmd=$(echo "$last" | sed "$pattern")
        echo -e "  \033[90m→\033[0m $new_cmd"
        eval "$new_cmd"
        return
    fi
    
    local first_word="${last%% *}"
    local new_cmd="$first_word $*"
    echo -e "  \033[90m→\033[0m $new_cmd"
    eval "$new_cmd"
}