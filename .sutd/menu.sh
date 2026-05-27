#!/bin/bash

SUTD_DIR="$HOME/.sutd"
[ -f "$SUTD_DIR/info.conf" ] && source "$SUTD_DIR/info.conf"
[ -f "$SUTD_DIR/lib.sh" ]    && source "$SUTD_DIR/lib.sh"

export COLOR_WHITE='\033[37m'
export COLOR_GRAY='\033[90m'
export COLOR_GREEN='\033[32m'
export COLOR_RED='\033[31m'
export COLOR_YELLOW='\033[33m'
export COLOR_BLUE='\033[38;5;75m'
export COLOR_PURPLE='\033[38;5;141m'
export COLOR_RESET='\033[0m'
export SUTD_DIR

apply_theme

field()   { printf "  ${COLOR_WHITE}%-10s:${COLOR_RESET} %b\n" "$1" "$2"; }
divider() { echo -e "${COLOR_GRAY}  --------------------------------------------------${COLOR_RESET}"; }
section() { echo -e "${COLOR_WHITE}  $1${COLOR_RESET}"; }
export -f field divider section

strip_ansi() {
    echo -e "$1" | sed -E 's/\x1b$$[0-9;]*[a-zA-Z]//g'
}

panel() {
    local content="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    
    local bg="${COLOR_BG}"
    local rst="${COLOR_BG_RESET}"
    
    while IFS= read -r line; do
        local visible
        visible=$(strip_ansi "$line")
        local pad=$(( cols - ${#visible} ))
        [ "$pad" -lt 0 ] && pad=0
        printf "${bg}%b%*s${rst}\n" "$line" "$pad" ""
    done <<< "$content"
}

show_header() {
    clear
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
}

show_title_bar() {
    local title="$1"
    local idx=$2
    local total=$3
    
    local content="  ${COLOR_WHITE}▸ ${COLOR_ACCENT}${title}${COLOR_RESET}  ${COLOR_GRAY}[$((idx+1))/${total}]${COLOR_RESET}"
    panel "$content"
}

show_footer_bar() {
    local content="  ${COLOR_GRAY}[${COLOR_ACCENT}←/→${COLOR_GRAY}] navigate   [${COLOR_ACCENT}q${COLOR_GRAY}] exit to terminal   [${COLOR_ACCENT}h${COLOR_GRAY}] help${COLOR_RESET}"
    panel "$content"
}

SLIDES=(
    "Overview|10-host.sh 30-system.sh 49-server-age.sh 47-streak.sh 48-uptime-record.sh"
    "Network|20-network.sh"
    "Resources|40-resources.sh 52-progress-bars.sh 53-ascii-graph.sh"
    "Top Processes|46-top-processes.sh"
    "Services|50-services.sh"
    "Docker|60-docker.sh"
    "SSL Certs|45-ssl-certs.sh"
    "Security|70-security.sh 73-sshd-config.sh"
    "Sessions|67-screen-sessions.sh"
    "Updates|82-package-updates.sh 80-updates.sh"
    "Web|63-nginx-stats.sh"
    "Achievements|51-achievements.sh"
    "Last Commands|95-last-commands.sh"
)

show_slide() {
    local idx=$1
    local slide="${SLIDES[$idx]}"
    local title="${slide%%|*}"
    local modules="${slide##*|}"
    
    show_header
    
    show_title_bar "$title" "$idx" "${#SLIDES[@]}"
    echo ""
    
    for m in $modules; do
        if [ -x "$SUTD_DIR/modules/$m" ]; then
            bash "$SUTD_DIR/modules/$m"
        fi
    done
    
    echo ""
    show_footer_bar
}

current=0
total=${#SLIDES[@]}

while true; do
    show_slide $current
    
    read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key2
        key="$key$key2"
    fi
    
    case "$key" in
        $'\x1b[C'|d|l) current=$(( (current + 1) % total )) ;;
        $'\x1b[D'|a|j) current=$(( (current - 1 + total) % total )) ;;
        q|Q|"")        clear; break ;;
        h|H)
            show_header
            help_content="  ${COLOR_WHITE}Help:${COLOR_RESET}
    ${COLOR_ACCENT}→${COLOR_RESET}  /  ${COLOR_ACCENT}d${COLOR_RESET}  /  ${COLOR_ACCENT}l${COLOR_RESET}    next slide
    ${COLOR_ACCENT}←${COLOR_RESET}  /  ${COLOR_ACCENT}a${COLOR_RESET}  /  ${COLOR_ACCENT}j${COLOR_RESET}    previous slide
    ${COLOR_ACCENT}q${COLOR_RESET}  /  ${COLOR_ACCENT}Enter${COLOR_RESET}      exit to terminal
    ${COLOR_ACCENT}h${COLOR_RESET}                  this help"
            panel "$help_content"
            echo ""
            echo -e "  ${COLOR_GRAY}Press Enter to continue...${COLOR_RESET}"
            read -r _
            ;;
    esac
done