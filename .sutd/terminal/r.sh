#!/bin/bash

r() {
    local target="$1"
    
    if [ -z "$target" ]; then
        echo -e "  \033[90m→\033[0m source ~/.bashrc"
        source "$HOME/.bashrc"
        echo -e "  \033[32m✓\033[0m reloaded"
        return
    fi
    
    case "$target" in
        -h|--help)
            cat << 'EOF'
  r — reload shell config or a specific file

  r                         source ~/.bashrc
  r .sutd                   re-source all ~/.sutd/terminal/*.sh
  r <file>                  source the given file
  r <name>                  source ~/.sutd/terminal/<name>.sh
  r -h                      this help
EOF
            return
            ;;
        .sutd|sutd)
            local count=0
            for f in "$HOME/.sutd/terminal"/*.sh; do
                [ -r "$f" ] && source "$f" && count=$((count+1))
            done
            echo -e "  \033[32m✓\033[0m sourced $count files from ~/.sutd/terminal/"
            return
            ;;
    esac
    
    if [ -f "$target" ]; then
        echo -e "  \033[90m→\033[0m source $target"
        source "$target"
        echo -e "  \033[32m✓\033[0m reloaded"
        return
    fi
    
    local ext="$HOME/.sutd/terminal/${target}.sh"
    if [ -f "$ext" ]; then
        echo -e "  \033[90m→\033[0m source $ext"
        source "$ext"
        echo -e "  \033[32m✓\033[0m reloaded $target"
        return
    fi
    
    echo -e "  \033[31m✗\033[0m no such target: $target"
    return 1
}

alias reload='r'

_r_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local exts
    exts=$(ls "$HOME/.sutd/terminal/" 2>/dev/null | sed 's/\.sh$//')
    COMPREPLY=( $(compgen -W "$exts .sutd -h" -- "$cur") $(compgen -f -- "$cur") )
}
complete -F _r_complete r reload