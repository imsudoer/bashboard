#!/bin/bash

__CHAIN_DIR="$HOME/.sutd/data/chains"
mkdir -p "$__CHAIN_DIR"

chain() {
    local cmd="$1"; shift
    
    case "$cmd" in
        ""|ls|list)
            if [ -z "$(ls "$__CHAIN_DIR" 2>/dev/null)" ]; then
                echo "  (no chains yet)"
                echo "  create with:  chain new <name>"
                return
            fi
            echo -e "  \033[37mChains:\033[0m"
            for f in "$__CHAIN_DIR"/*; do
                [ -f "$f" ] || continue
                local n=$(basename "$f")
                local lines=$(wc -l < "$f")
                printf "    \033[38;5;208m●\033[0m %-20s \033[90m%s steps\033[0m\n" "$n" "$lines"
            done
            ;;
        new)
            local name="$1"
            [ -z "$name" ] && { echo "  usage: chain new <name>"; return 1; }
            touch "$__CHAIN_DIR/$name"
            echo -e "  \033[32m✓\033[0m created chain: $name"
            ;;
        add)
            local name="$1"; shift
            [ -z "$name" ] || [ $# -eq 0 ] && { echo "  usage: chain add <name> \"<command>\""; return 1; }
            [ ! -f "$__CHAIN_DIR/$name" ] && touch "$__CHAIN_DIR/$name"
            echo "$*" >> "$__CHAIN_DIR/$name"
            echo -e "  \033[32m✓\033[0m added to $name: $*"
            ;;
        rm|remove)
            local name="$1"
            [ -z "$name" ] && { echo "  usage: chain rm <name>"; return 1; }
            rm -f "$__CHAIN_DIR/$name"
            echo -e "  \033[31m✗\033[0m removed: $name"
            ;;
        show)
            local name="$1"
            [ -f "$__CHAIN_DIR/$name" ] || { echo "  no such chain: $name"; return 1; }
            echo -e "  \033[37mChain: \033[38;5;208m$name\033[0m"
            local i=1
            while IFS= read -r line; do
                printf "  \033[90m%2d)\033[0m %s\n" "$i" "$line"
                i=$((i+1))
            done < "$__CHAIN_DIR/$name"
            ;;
        edit)
            local name="$1"
            [ -z "$name" ] && { echo "  usage: chain edit <name>"; return 1; }
            ${EDITOR:-nano} "$__CHAIN_DIR/$name"
            ;;
        rmstep)
            local name="$1"; local n="$2"
            [ -z "$name" ] || [ -z "$n" ] && { echo "  usage: chain rmstep <name> <step-num>"; return 1; }
            sed -i "${n}d" "$__CHAIN_DIR/$name"
            echo -e "  \033[31m✗\033[0m step $n removed from $name"
            ;;
        run)
            local name="$1"; shift
            [ -f "$__CHAIN_DIR/$name" ] || { echo "  no such chain: $name"; return 1; }
            
            local confirm=0
            for arg in "$@"; do
                [ "$arg" = "-c" ] || [ "$arg" = "--confirm" ] && confirm=1
            done
            
            echo -e "  \033[37mRunning chain: \033[38;5;208m$name\033[0m"
            local step=1
            local total=$(wc -l < "$__CHAIN_DIR/$name")
            
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                echo ""
                echo -e "  \033[90m[$step/$total]\033[0m \033[38;5;75m▸\033[0m $line"
                
                if [ "$confirm" -eq 1 ]; then
                    read -p "    run? [Y/n/s(kip)/q(uit)]: " ans
                    case "$ans" in
                        n|N) echo -e "    \033[33mskipped\033[0m"; step=$((step+1)); continue ;;
                        s|S) echo -e "    \033[33mskipped\033[0m"; step=$((step+1)); continue ;;
                        q|Q) echo -e "    \033[31maborted\033[0m"; return 1 ;;
                    esac
                fi
                
                eval "$line"
                local rc=$?
                if [ "$rc" -ne 0 ]; then
                    echo -e "  \033[31m✗ step $step failed (exit $rc)\033[0m"
                    read -p "  continue? [y/N]: " ans
                    [[ ! "$ans" =~ ^[yY]$ ]] && return 1
                fi
                step=$((step+1))
            done < "$__CHAIN_DIR/$name"
            
            echo ""
            echo -e "  \033[32m✓ chain completed\033[0m"
            ;;
        -h|--help|help)
            cat << 'EOF'
  chain — command pipelines

  chain                       list chains
  chain new <name>            create
  chain add <name> "<cmd>"    append step
  chain run <name>            execute all
  chain run <name> -c         confirm each step
  chain show <name>           show steps
  chain edit <name>           edit in $EDITOR
  chain rmstep <name> <n>     remove step n
  chain rm <name>             delete chain
EOF
            ;;
        *)
            echo "  unknown subcommand: $cmd"
            echo "  try: chain help"
            ;;
    esac
}

_chain_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
        chain) COMPREPLY=( $(compgen -W "new add run show edit rm rmstep ls help" -- "$cur") ) ;;
        run|show|edit|rm|rmstep|add)
            local names
            names=$(ls "$__CHAIN_DIR" 2>/dev/null)
            COMPREPLY=( $(compgen -W "$names" -- "$cur") )
            ;;
    esac
}
complete -F _chain_complete chain