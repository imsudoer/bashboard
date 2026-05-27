#!/bin/bash

__PROJ_HIST_DIR="$HOME/.sutd/data/proj_histories"
mkdir -p "$__PROJ_HIST_DIR"

export __SUTD_DEFAULT_HISTFILE="${__SUTD_DEFAULT_HISTFILE:-$HISTFILE}"

__proj_hash() {
    echo -n "$1" | md5sum | cut -c1-12
}

__proj_find_root() {
    local d="$PWD"
    while [ "$d" != "/" ] && [ -n "$d" ]; do
        if [ -d "$d/.git" ] || [ -f "$d/.sutd-project" ]; then
            echo "$d"
            return
        fi
        d=$(dirname "$d")
    done
}

__proj_history_switch() {
    local proj_root
    proj_root=$(__proj_find_root)
    
    if [ -n "$proj_root" ]; then
        if [ "$__SUTD_PROJ_ROOT" = "$proj_root" ]; then
            return
        fi
        
        history -a 2>/dev/null
        
        local hash
        hash=$(__proj_hash "$proj_root")
        local new_hist="$__PROJ_HIST_DIR/${hash}.history"
        touch "$new_hist"
        
        if [ ! -f "${new_hist}.label" ]; then
            echo "$proj_root" > "${new_hist}.label"
        fi
        
        HISTFILE="$new_hist"
        history -c
        history -r 2>/dev/null
        export __SUTD_PROJ_ROOT="$proj_root"
    else
        if [ -n "$__SUTD_PROJ_ROOT" ]; then
            history -a 2>/dev/null
            HISTFILE="$__SUTD_DEFAULT_HISTFILE"
            history -c
            history -r 2>/dev/null
            unset __SUTD_PROJ_ROOT
        fi
    fi
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__proj_history_switch"
else
    case ";$PROMPT_COMMAND;" in
        *";__proj_history_switch;"*) ;;
        *) PROMPT_COMMAND="__proj_history_switch;$PROMPT_COMMAND" ;;
    esac
fi

projhist() {
    case "$1" in
        ""|ls)
            if [ -z "$(ls "$__PROJ_HIST_DIR" 2>/dev/null)" ]; then
                echo "  (no project histories yet)"
                return
            fi
            echo -e "  \033[37mProject histories:\033[0m"
            for label in "$__PROJ_HIST_DIR"/*.label; do
                [ -f "$label" ] || continue
                local path lines hist
                path=$(cat "$label")
                hist="${label%.label}"
                lines=$(wc -l < "$hist" 2>/dev/null || echo 0)
                local marker="  "
                [ "$path" = "$__SUTD_PROJ_ROOT" ] && marker="\033[38;5;208m●\033[0m "
                printf "  %b %-50s \033[90m%s lines\033[0m\n" "$marker" "$path" "$lines"
            done
            ;;
        current)
            if [ -n "$__SUTD_PROJ_ROOT" ]; then
                echo -e "  current project: \033[38;5;208m${__SUTD_PROJ_ROOT}\033[0m"
                echo -e "  histfile: $HISTFILE"
            else
                echo "  not in a project (using default history)"
            fi
            ;;
        mark)
            touch "$PWD/.sutd-project"
            echo -e "  \033[32m✓\033[0m marked $PWD as a project"
            __proj_history_switch
            ;;
        unmark)
            rm -f "$PWD/.sutd-project"
            echo -e "  \033[31m✗\033[0m unmarked $PWD"
            ;;
        clear)
            local proj_root
            proj_root=$(__proj_find_root)
            [ -z "$proj_root" ] && { echo "  not in a project"; return 1; }
            local hash
            hash=$(__proj_hash "$proj_root")
            > "$__PROJ_HIST_DIR/${hash}.history"
            history -c
            echo -e "  \033[31m✗\033[0m history cleared for $proj_root"
            ;;
        -h|--help)
            cat << 'EOF'
  projhist — per-project history

  Auto-switches when you cd into a directory containing
  .git or .sutd-project. Each project gets its own history.

  projhist               list all project histories
  projhist current       show active project
  projhist mark          mark current dir as project
  projhist unmark        remove project marker
  projhist clear         wipe history for current project
EOF
            ;;
    esac
}