#!/bin/bash

__ENV_DIR="$HOME/.sutd/data/env-checks"
mkdir -p "$__ENV_DIR"

__env_seed() {
    [ -f "$__ENV_DIR/web.txt" ] && return
    
    cat > "$__ENV_DIR/web.txt" << 'EOF'
curl
wget
git
nginx
EOF
    cat > "$__ENV_DIR/py.txt" << 'EOF'
python3
pip3
git
curl
EOF
    cat > "$__ENV_DIR/node.txt" << 'EOF'
node
npm
git
curl
EOF
    cat > "$__ENV_DIR/docker.txt" << 'EOF'
docker
docker-compose
git
EOF
}

env-check() {
    __env_seed
    
    if [ $# -eq 0 ]; then
        echo -e "  \033[37mAvailable presets:\033[0m"
        for f in "$__ENV_DIR"/*.txt; do
            [ -f "$f" ] || continue
            local name=$(basename "$f" .txt)
            local count=$(wc -l < "$f")
            printf "    \033[38;5;208m▸\033[0m %-15s \033[90m%d tools\033[0m\n" "$name" "$count"
        done
        echo ""
        echo "  Usage:  env-check <preset>"
        echo "          env-check -l <preset>     edit preset"
        echo "          env-check curl git docker check individual tools"
        return
    fi
    
    if [ "$1" = "-l" ] || [ "$1" = "--edit" ]; then
        local f="$__ENV_DIR/${2}.txt"
        [ ! -f "$f" ] && touch "$f"
        ${EDITOR:-nano} "$f"
        return
    fi
    
    local tools=()
    if [ $# -eq 1 ] && [ -f "$__ENV_DIR/${1}.txt" ]; then
        echo -e "  \033[37mPreset: \033[38;5;208m$1\033[0m"
        while IFS= read -r line; do
            [ -z "$line" ] || [[ "$line" =~ ^# ]] && continue
            tools+=("$line")
        done < "$__ENV_DIR/${1}.txt"
    else
        tools=("$@")
    fi
    
    local ok=0 fail=0
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            local path version
            path=$(command -v "$tool")
            version=$("$tool" --version 2>&1 | head -1 | tr -d '\n' | cut -c1-50)
            printf "    \033[32m●\033[0m %-15s \033[90m%s\033[0m\n" "$tool" "$version"
            ok=$((ok+1))
        else
            printf "    \033[31m●\033[0m %-15s \033[31mnot installed\033[0m\n" "$tool"
            fail=$((fail+1))
        fi
    done
    
    echo ""
    echo -e "  \033[90mResult:\033[0m \033[32m$ok ok\033[0m / \033[31m$fail missing\033[0m"
    [ "$fail" -gt 0 ] && return 1 || return 0
}

_envcheck_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local names
    names=$(ls "$__ENV_DIR" 2>/dev/null | sed 's/\.txt$//')
    COMPREPLY=( $(compgen -W "$names -l" -- "$cur") )
}
complete -F _envcheck_complete env-check