#!/bin/bash

__mvcp_size() {
    du -sb "$1" 2>/dev/null | awk '{print $1}'
}

__mvcp_human() {
    local b="$1"
    if [ "$b" -lt 1024 ]; then echo "${b}B"
    elif [ "$b" -lt 1048576 ]; then echo "$((b/1024))KB"
    elif [ "$b" -lt 1073741824 ]; then echo "$((b/1048576))MB"
    else echo "$((b/1073741824))GB"
    fi
}

__mvcp_confirm_if_big() {
    local src="$1"
    local size
    size=$(__mvcp_size "$src")
    [ -z "$size" ] && return 0
    
    if [ "$size" -gt 104857600 ]; then
        local h
        h=$(__mvcp_human "$size")
        echo -e "  \033[33m⚠\033[0m large operation: $src ($h)"
        read -p "  Continue? [Y/n]: " ans
        [[ "$ans" =~ ^[nN]$ ]] && return 1
    fi
    return 0
}

cpr() {
    local args=()
    local sources=()
    local dest=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                cat << 'EOF'
  cpr — cp with progress bar

  cpr <src> <dst>             copy with rsync --progress
  cpr -r <dir> <dst>          recursive
  cpr <src1> <src2> <dst>     multiple sources
  cpr -h                      this help

  Uses rsync under the hood. Asks for confirmation on >100MB ops.
EOF
                return
                ;;
            -r|--recursive)
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    [ ${#args[@]} -lt 2 ] && { echo "  usage: cpr <src> <dst>"; return 1; }
    
    dest="${args[-1]}"
    sources=("${args[@]:0:${#args[@]}-1}")
    
    if ! command -v rsync &>/dev/null; then
        echo "  rsync not installed, falling back to cp"
        cp -rv "${sources[@]}" "$dest"
        return
    fi
    
    for s in "${sources[@]}"; do
        __mvcp_confirm_if_big "$s" || { echo "  aborted"; return 1; }
    done
    
    rsync -ah --info=progress2 --stats "${sources[@]}" "$dest"
    local rc=$?
    
    if [ "$rc" -eq 0 ]; then
        echo -e "  \033[32m✓\033[0m copied"
    else
        echo -e "  \033[31m✗\033[0m rsync exit $rc"
    fi
    return $rc
}

mvr() {
    if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cat << 'EOF'
  mvr — mv with progress bar

  mvr <src> <dst>             move with rsync + delete source

  Same options as cpr. Source is removed only after successful copy.
EOF
        return
    fi
    
    local args=("$@")
    local dest="${args[-1]}"
    local sources=("${args[@]:0:${#args[@]}-1}")
    
    if ! command -v rsync &>/dev/null; then
        mv "${sources[@]}" "$dest"
        return
    fi
    
    for s in "${sources[@]}"; do
        __mvcp_confirm_if_big "$s" || { echo "  aborted"; return 1; }
    done
    
    rsync -ah --info=progress2 --remove-source-files "${sources[@]}" "$dest"
    local rc=$?
    
    if [ "$rc" -eq 0 ]; then
        for s in "${sources[@]}"; do
            if [ -d "$s" ]; then
                find "$s" -depth -type d -empty -delete 2>/dev/null
            fi
        done
        echo -e "  \033[32m✓\033[0m moved"
    else
        echo -e "  \033[31m✗\033[0m rsync exit $rc — source not removed"
    fi
    return $rc
}

_cpr_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -f -- "$cur") )
}
complete -F _cpr_complete cpr mvr