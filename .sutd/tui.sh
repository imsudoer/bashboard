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
divider() { echo -e "${COLOR_GRAY}  ──────────────────────────────────────${COLOR_RESET}"; }
section() { echo -e "${COLOR_WHITE}  $1${COLOR_RESET}"; }
export -f field divider section

SLIDES=(
    "Overview|10-host.sh 30-system.sh 49-server-age.sh 47-streak.sh 48-uptime-record.sh"
    "Network|20-network.sh"
    "Resources|40-resources.sh 52-progress-bars.sh"
    "Graph|53-ascii-graph.sh"
    "Top Procs|46-top-processes.sh"
    "Services|50-services.sh"
    "Docker|60-docker.sh"
    "SSL Certs|45-ssl-certs.sh"
    "Security|70-security.sh 73-sshd-config.sh"
    "Sessions|67-screen-sessions.sh"
    "Updates|82-package-updates.sh 80-updates.sh"
    "Web|63-nginx-stats.sh"
    "Achievements|51-achievements.sh"
    "Last Cmds|95-last-commands.sh"
)

SIDEBAR_W=18
HEADER_H=11

tui_init() {
    tput smcup
    tput civis
    stty -echo
    trap tui_cleanup EXIT INT TERM
}

tui_cleanup() {
    tput cnorm
    stty echo
    tput rmcup
    clear
}

tui_size() {
    COLS=$(tput cols)
    ROWS=$(tput lines)
}

tui_at() {
    tput cup "$1" "$2"
}

tui_draw_header() {
    tui_at 0 0
    echo -e "${COLOR_ACCENT}  ____            _     ____                      _   ${COLOR_RESET}"
    echo -e "${COLOR_ACCENT} |  _ \          | |   |  _ \                    | |  ${COLOR_RESET}"
    echo -e "${COLOR_ACCENT} | |_) | __ _ ___| |__ | |_) | ___   __ _ _ __ __| |  ${COLOR_RESET}"
    echo -e "${COLOR_ACCENT} |  _ < / _\` / __| '_ \|  _ < / _ \ / _\` | '__/ _\` |  ${COLOR_RESET}"
    echo -e "${COLOR_ACCENT} | |_) | (_| \__ \ | | | |_) | (_) | (_| | | | (_| |  ${COLOR_RESET}"
    echo -e "${COLOR_ACCENT} |____/ \__,_|___/_| |_|____/ \___/ \__,_|_|  \__,_| © OnlySq.${COLOR_RESET}"
}

tui_draw_sidebar() {
    local selected=$1
    local i=0
    local start_row=$((HEADER_H))
    
    for entry in "${SLIDES[@]}"; do
        local title="${entry%%|*}"
        tui_at $((start_row + i)) 0
        
        if [ "$i" = "$selected" ]; then
            printf "${COLOR_BG}${COLOR_ACCENT} ▸ %-15s${COLOR_BG_RESET}${COLOR_RESET}" "$title"
        else
            printf "   ${COLOR_GRAY}%-15s${COLOR_RESET}" "$title"
        fi
        i=$((i+1))
    done
}

tui_draw_separator() {
    local r=$HEADER_H
    while [ "$r" -lt "$((ROWS - 2))" ]; do
        tui_at "$r" "$SIDEBAR_W"
        echo -e "${COLOR_GRAY}│${COLOR_RESET}"
        r=$((r+1))
    done
}

tui_clear_content() {
    local r=$HEADER_H
    while [ "$r" -lt "$((ROWS - 2))" ]; do
        tui_at "$r" "$((SIDEBAR_W + 2))"
        printf "%*s" "$((COLS - SIDEBAR_W - 2))" ""
        r=$((r+1))
    done
}

tui_draw_content() {
    local idx=$1
    local slide="${SLIDES[$idx]}"
    local title="${slide%%|*}"
    local modules="${slide##*|}"
    
    tui_clear_content
    
    local tmp
    tmp=$(mktemp)
    
    {
        echo -e "${COLOR_ACCENT}▸ ${title}${COLOR_RESET}"
        echo ""
        for m in $modules; do
            [ -x "$SUTD_DIR/modules/$m" ] && bash "$SUTD_DIR/modules/$m" 2>/dev/null
        done
    } > "$tmp"
    
    local r=$HEADER_H
    local max_r=$((ROWS - 3))
    while IFS= read -r line && [ "$r" -lt "$max_r" ]; do
        tui_at "$r" "$((SIDEBAR_W + 2))"
        local trimmed="${line:0:$((COLS - SIDEBAR_W - 2))}"
        printf "%b" "$trimmed"
        r=$((r+1))
    done < "$tmp"
    
    rm -f "$tmp"
}

tui_draw_footer() {
    tui_at "$((ROWS - 1))" 0
    printf "${COLOR_BG} ${COLOR_ACCENT}↑/↓${COLOR_GRAY} nav   ${COLOR_ACCENT}r${COLOR_GRAY} refresh   ${COLOR_ACCENT}m${COLOR_GRAY} menu mode   ${COLOR_ACCENT}q${COLOR_GRAY} quit${COLOR_RESET}${COLOR_BG_RESET}"
}

tui_main() {
    tui_init
    tui_size
    
    local current=0
    local total=${#SLIDES[@]}
    
    clear
    tui_draw_header
    tui_draw_separator
    tui_draw_sidebar "$current"
    tui_draw_content "$current"
    tui_draw_footer
    
    while true; do
        read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key2
            key="$key$key2"
        fi
        
        case "$key" in
            $'\x1b[A'|k) current=$(( (current - 1 + total) % total )) ;;
            $'\x1b[B'|j) current=$(( (current + 1) % total )) ;;
            r|R)
                tui_draw_content "$current"
                continue
                ;;
            m|M)
                tui_cleanup
                exec "$SUTD_DIR/menu.sh"
                ;;
            q|Q|"")
                tui_cleanup
                exit 0
                ;;
            *) continue ;;
        esac
        
        tui_draw_sidebar "$current"
        tui_draw_content "$current"
    done
}

tui_main