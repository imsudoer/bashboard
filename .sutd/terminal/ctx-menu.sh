#!/bin/bash

__ctx_menu() {
    clear
    echo -e "\033[38;5;208m  ┌─ Context menu ─────────────────┐\033[0m"
    
    local opts=()
    
    if [ -d ".git" ] || git rev-parse --git-dir &>/dev/null 2>&1; then
        opts+=("git status:git status")
        opts+=("git log:git log --oneline -20")
        opts+=("git diff:git diff")
        opts+=("git pull:git pull")
        opts+=("git stash:git stash")
    fi
    
    if [ -f "docker-compose.yml" ] || [ -f "compose.yml" ]; then
        opts+=("compose up:docker compose up -d")
        opts+=("compose down:docker compose down")
        opts+=("compose logs:docker compose logs -f --tail=50")
        opts+=("compose ps:docker compose ps")
    fi
    
    if [ -f "package.json" ]; then
        opts+=("npm install:npm install")
        opts+=("npm run dev:npm run dev")
        opts+=("npm test:npm test")
    fi
    
    if [ -f "Makefile" ]; then
        opts+=("make:make")
        opts+=("make clean:make clean")
    fi
    
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        opts+=("pip install:pip install -r requirements.txt")
        opts+=("python venv:python3 -m venv .venv")
    fi
    
    opts+=("show resources:free -h && df -h /")
    opts+=("listening ports:ss -tlnp 2>/dev/null || ss -tln")
    opts+=("top procs:ps aux --sort=-%cpu | head -10")
    opts+=("disk usage here:du -sh * 2>/dev/null | sort -hr | head -10")
    opts+=("open menu:bash ~/.sutd/menu.sh")
    opts+=("open helpme:helpme")
    
    local i=1
    for opt in "${opts[@]}"; do
        local label="${opt%%:*}"
        printf "  \033[90m%2d)\033[0m \033[37m%s\033[0m\n" "$i" "$label"
        i=$((i+1))
    done
    echo -e "\033[38;5;208m  └────────────────────────────────┘\033[0m"
    
    read -p "  Select (q to cancel): " choice
    [[ "$choice" =~ ^[qQ]$ ]] || [ -z "$choice" ] && { echo ""; return; }
    [[ ! "$choice" =~ ^[0-9]+$ ]] && { echo ""; return; }
    [ "$choice" -lt 1 ] || [ "$choice" -gt "${#opts[@]}" ] && { echo ""; return; }
    
    local selected="${opts[$((choice-1))]}"
    local cmd="${selected#*:}"
    echo ""
    echo -e "  \033[90m→\033[0m $cmd"
    eval "$cmd"
}

__ctx_menu_wrapper() {
    __ctx_menu
    READLINE_LINE=""
    READLINE_POINT=0
}

bind -x "\"${CTX_MENU_BIND:-\\C-g}\": __ctx_menu_wrapper" 2>/dev/null