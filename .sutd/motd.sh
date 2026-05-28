#!/bin/bash

export SUTD_DIR="$HOME/.sutd"
# [ -f "$SUTD_DIR/info.conf" ] && source "$SUTD_DIR/info.conf"
if [ -f "$SUTD_DIR/info.conf" ]; then
    set -a
    source "$SUTD_DIR/info.conf"
    set +a
fi
[ -f "$SUTD_DIR/lib.sh" ]    && source "$SUTD_DIR/lib.sh"

export COLOR_WHITE='\033[37m'
export COLOR_GRAY='\033[90m'
export COLOR_GREEN='\033[32m'
export COLOR_RED='\033[31m'
export COLOR_YELLOW='\033[33m'
export COLOR_BLUE='\033[38;5;75m'
export COLOR_PURPLE='\033[38;5;141m'
export COLOR_RESET='\033[0m'

apply_theme

field()   { printf "  ${COLOR_WHITE}%-10s:${COLOR_RESET} %b\n" "$1" "$2"; }
divider() { echo -e "${COLOR_GRAY}  --------------------------------------------------${COLOR_RESET}"; }
section() { echo -e "${COLOR_WHITE}  $1${COLOR_RESET}"; }
export -f field divider section

case "${INTERFACE_MODE:-1}" in
    1)
        if [ -t 0 ] && [ -t 1 ] && [ -x "$SUTD_DIR/menu.sh" ]; then
            exec "$SUTD_DIR/menu.sh"
        fi
        ;;
    2)
        if [ -t 0 ] && [ -t 1 ] && [ -x "$SUTD_DIR/tui.sh" ]; then
            exec "$SUTD_DIR/tui.sh"
        fi
        ;;
    0|*)
        ;;
esac

echo -e "${COLOR_ACCENT}"
cat << 'EOF'
  ____            _     ____                      _ 
 |  _ \          | |   |  _ \                    | |
 | |_) | __ _ ___| |__ | |_) | ___   __ _ _ __ __| |
 |  _ < / _` / __| '_ \|  _ < / _ \ / _` | '__/ _` |
 | |_) | (_| \__ \ | | | |_) | (_) | (_| | | | (_| |
 |____/ \__,_|___/_| |_|____/ \___/ \__,_|_|  \__,_| © OnlySq.
EOF
echo -e "${COLOR_RESET}"
echo -e "${COLOR_WHITE}  Welcome to OnlySq Infrastructure${COLOR_RESET}"
divider

for module in "$SUTD_DIR"/modules/*.sh; do
    [ -f "$module" ] || continue
    mod_name=$(basename "$module" .sh | sed 's/^[0-9]*-//' | tr '-' '_')
    var_name="ENABLE_$(echo "$mod_name" | tr '[:lower:]' '[:upper:]')"
    if [ "${!var_name}" = "1" ]; then
        bash "$module"
    fi
done

echo ""