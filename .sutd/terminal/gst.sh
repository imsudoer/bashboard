#!/bin/bash

__GST_FILE="$HOME/.sutd/data/gst_repos.dat"
mkdir -p "$(dirname "$__GST_FILE")"
touch "$__GST_FILE"

__gst_autoadd() {
    [ -d "$PWD/.git" ] || return
    grep -qxF "$PWD" "$__GST_FILE" 2>/dev/null && return
    echo "$PWD" >> "$__GST_FILE"
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__gst_autoadd"
else
    case ";$PROMPT_COMMAND;" in
        *";__gst_autoadd;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;__gst_autoadd" ;;
    esac
fi

__gst_repo_status() {
    local repo="$1"
    [ ! -d "$repo/.git" ] && return
    
    local name=$(basename "$repo")
    local branch ahead behind changes stashes
    
    branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || git -C "$repo" rev-parse --short HEAD 2>/dev/null)
    changes=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)
    stashes=$(git -C "$repo" stash list 2>/dev/null | wc -l)
    
    local tracking
    tracking=$(git -C "$repo" rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$tracking" ]; then
        behind=$(echo "$tracking" | awk '{print $1}')
        ahead=$(echo "$tracking" | awk '{print $2}')
    fi
    
    local color="\033[32m"
    local icon="●"
    [ "${changes:-0}" -gt 0 ] && color="\033[33m" && icon="●"
    [ "${changes:-0}" -gt 20 ] && color="\033[31m"
    
    local extra=""
    [ "${ahead:-0}" -gt 0 ]   && extra="${extra} \033[32m↑${ahead}\033[0m"
    [ "${behind:-0}" -gt 0 ]  && extra="${extra} \033[31m↓${behind}\033[0m"
    [ "${changes:-0}" -gt 0 ] && extra="${extra} \033[33m±${changes}\033[0m"
    [ "${stashes:-0}" -gt 0 ] && extra="${extra} \033[38;5;141m⚑${stashes}\033[0m"
    
    printf "  ${color}${icon}\033[0m %-25s \033[90m(%s)\033[0m\033[37m%b\033[0m \033[90m%s\033[0m\n" \
        "$name" "$branch" "$extra" "$repo"
}

gst() {
    case "$1" in
        -h|--help)
            cat << 'EOF'
  gst — git status across tracked repos

  gst                       status of current repo
  gst -a, --all             status of all tracked repos
  gst -l, --list            list tracked repos
  gst add [path]            track repo (default: current dir)
  gst rm [path]             untrack repo
  gst -d                    diff stat of current repo
  gst clean                 remove non-existent paths from tracking
  gst -h                    this help

  Repos are auto-tracked when you cd into a directory containing .git
EOF
            return
            ;;
        -a|--all)
            if [ ! -s "$__GST_FILE" ]; then
                echo "  no tracked repos yet"
                return
            fi
            echo -e "  \033[37mTracked repos:\033[0m"
            while IFS= read -r repo; do
                [ -z "$repo" ] && continue
                __gst_repo_status "$repo"
            done < "$__GST_FILE"
            return
            ;;
        -l|--list)
            cat "$__GST_FILE" | sed 's/^/  /'
            return
            ;;
        add)
            local target="${2:-$PWD}"
            target=$(realpath "$target" 2>/dev/null || echo "$target")
            [ ! -d "$target/.git" ] && { echo "  not a git repo: $target"; return 1; }
            grep -qxF "$target" "$__GST_FILE" && { echo "  already tracked: $target"; return; }
            echo "$target" >> "$__GST_FILE"
            echo -e "  \033[32m✓\033[0m tracking $target"
            return
            ;;
        rm|remove)
            local target="${2:-$PWD}"
            target=$(realpath "$target" 2>/dev/null || echo "$target")
            sed -i "\|^${target}$|d" "$__GST_FILE"
            echo -e "  \033[31m✗\033[0m untracked $target"
            return
            ;;
        clean)
            local before after
            before=$(wc -l < "$__GST_FILE")
            local tmp=$(mktemp)
            while IFS= read -r repo; do
                [ -d "$repo/.git" ] && echo "$repo" >> "$tmp"
            done < "$__GST_FILE"
            mv "$tmp" "$__GST_FILE"
            after=$(wc -l < "$__GST_FILE")
            echo -e "  \033[32m✓\033[0m cleaned: $before → $after entries"
            return
            ;;
        -d|--diff)
            git diff --stat
            return
            ;;
    esac
    
    if ! git rev-parse --git-dir &>/dev/null; then
        echo "  not in a git repo"
        echo "  try:  gst -a  (all tracked)"
        return 1
    fi
    
    local root=$(git rev-parse --show-toplevel 2>/dev/null)
    __gst_repo_status "$root"
    
    local status
    status=$(git status --porcelain 2>/dev/null)
    
    if [ -n "$status" ]; then
        echo ""
        echo "$status" | while IFS= read -r line; do
            local code="${line:0:2}"
            local file="${line:3}"
            case "$code" in
                "M ") printf "    \033[32m+\033[0m staged    %s\n" "$file" ;;
                " M") printf "    \033[33m*\033[0m modified  %s\n" "$file" ;;
                "A ") printf "    \033[32m+\033[0m added     %s\n" "$file" ;;
                "D "|" D") printf "    \033[31m-\033[0m deleted   %s\n" "$file" ;;
                "??") printf "    \033[90m?\033[0m untracked %s\n" "$file" ;;
                "UU") printf "    \033[31m!\033[0m conflict  %s\n" "$file" ;;
                *)    printf "    \033[37m%s\033[0m %s\n" "$code" "$file" ;;
            esac
        done
    fi
}

_gst_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "-a --all -l --list add rm clean -d --diff -h" -- "$cur") )
}
complete -F _gst_complete gst