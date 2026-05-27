#!/bin/bash

__REMEMBER_FILE="$HOME/.sutd/data/remembered.dat"
mkdir -p "$(dirname "$__REMEMBER_FILE")"
touch "$__REMEMBER_FILE"

if [ -s "$__REMEMBER_FILE" ]; then
    set -a
    source "$__REMEMBER_FILE" 2>/dev/null
    set +a
fi

remember() {
    if [ $# -eq 0 ]; then
        if [ ! -s "$__REMEMBER_FILE" ]; then
            echo "  (nothing remembered)"
            echo "  usage: remember VAR=value"
            return
        fi
        echo -e "  \033[37mRemembered variables:\033[0m"
        while IFS='=' read -r key val; do
            [ -z "$key" ] && continue
            local masked="$val"
            if [[ "$key" == *KEY* ]] || [[ "$key" == *TOKEN* ]] || [[ "$key" == *SECRET* ]] || [[ "$key" == *PASS* ]]; then
                masked="$(echo "$val" | sed 's/./*/g' | cut -c1-8)..."
            fi
            printf "  \033[38;5;208m%-25s\033[0m \033[90m=\033[0m %s\n" "$key" "$masked"
        done < "$__REMEMBER_FILE"
        return
    fi
    
    case "$1" in
        -d|--delete)
            local key="$2"
            [ -z "$key" ] && { echo "  usage: remember -d <VAR>"; return 1; }
            sed -i "/^${key}=/d" "$__REMEMBER_FILE"
            unset "$key"
            echo -e "  \033[31m✗\033[0m forgot: $key"
            ;;
        -c|--clear)
            > "$__REMEMBER_FILE"
            echo -e "  \033[31m✗\033[0m forgot everything"
            ;;
        -s|--show)
            local key="$2"
            grep "^${key}=" "$__REMEMBER_FILE"
            ;;
        -e|--edit)
            ${EDITOR:-nano} "$__REMEMBER_FILE"
            set -a; source "$__REMEMBER_FILE"; set +a
            ;;
        -h|--help)
            cat << 'EOF'
  remember — persistent environment variables

  remember VAR=value          set and persist
  remember                    list all
  remember -d VAR             forget one
  remember -c                 forget all
  remember -e                 edit file in $EDITOR
  remember -s VAR             show raw value
EOF
            ;;
        *)
            if [[ "$1" == *=* ]]; then
                local key="${1%%=*}"
                local val="${1#*=}"
                sed -i "/^${key}=/d" "$__REMEMBER_FILE"
                echo "${key}=${val}" >> "$__REMEMBER_FILE"
                export "${key}=${val}"
                echo -e "  \033[32m✓\033[0m remembered: $key"
            else
                echo "  usage: remember VAR=value"
                return 1
            fi
            ;;
    esac
}