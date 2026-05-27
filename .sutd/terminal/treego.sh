#!/bin/bash

treego() {
    local depth=2
    local show_hidden=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--depth)  depth="$2"; shift 2 ;;
            -a|--all)    show_hidden=1; shift ;;
            -h|--help)
                cat << 'EOF'
  treego — tree view with interactive navigation

  treego                show tree (depth 2) and pick to cd
  treego -d 4           show 4 levels deep
  treego -a             include hidden dirs
  treego -h             this help
EOF
                return
                ;;
        esac
    done
    
    local tmpfile
    tmpfile=$(mktemp)
    
    local find_args=("-maxdepth" "$depth" "-type" "d")
    [ "$show_hidden" = "0" ] && find_args+=("-not" "-path" "*/.*")
    
    find . "${find_args[@]}" 2>/dev/null | sort > "$tmpfile"
    
    local dirs=()
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        [ "$d" = "." ] && continue
        dirs+=("$d")
    done < "$tmpfile"
    rm -f "$tmpfile"
    
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "  no subdirectories"
        return
    fi
    
    echo -e "  \033[37mPick a directory:\033[0m"
    
    local i=1
    for d in "${dirs[@]}"; do
        local depth_n
        depth_n=$(echo "$d" | awk -F/ '{print NF-1}')
        local indent=""
        for ((j=1; j<depth_n; j++)); do indent="$indent  "; done
        local name
        name=$(basename "$d")
        printf "  \033[90m%3d)\033[0m %s\033[38;5;208m▸\033[0m %s\n" "$i" "$indent" "$name"
        i=$((i+1))
    done
    
    echo ""
    read -p "  Select [q to cancel]: " choice
    
    [[ "$choice" =~ ^[qQ]$ ]] || [ -z "$choice" ] && return
    [[ ! "$choice" =~ ^[0-9]+$ ]] && { echo "  invalid"; return 1; }
    
    local target="${dirs[$((choice-1))]}"
    [ -z "$target" ] && { echo "  invalid index"; return 1; }
    
    echo -e "  \033[90m→\033[0m cd $target"
    cd "$target"
}