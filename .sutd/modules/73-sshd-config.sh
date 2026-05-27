#!/bin/bash

CONFIG=/etc/ssh/sshd_config
[ -r "$CONFIG" ] || exit 0

divider
section "SSH config:"

check_setting() {
    local key="$1"
    local recommended="$2"
    local danger="$3"
    
    local value
    value=$(grep -iE "^\s*${key}\s+" "$CONFIG" 2>/dev/null | tail -1 | awk '{print $2}')
    [ -z "$value" ] && value="(default)"
    
    local color="$COLOR_GREEN"
    local icon="●"
    
    if [ "$value" = "$danger" ]; then
        color="$COLOR_RED"; icon="✗"
    elif [ "$value" != "$recommended" ] && [ "$value" != "(default)" ]; then
        color="$COLOR_YELLOW"; icon="⚠"
    fi
    
    printf "    ${color}${icon}${COLOR_RESET} %-25s ${COLOR_GRAY}%s${COLOR_RESET}\n" "$key" "$value"
}

check_setting "PermitRootLogin"        "no"    "yes"
check_setting "PasswordAuthentication" "no"    "yes"
check_setting "PermitEmptyPasswords"   "no"    "yes"
check_setting "X11Forwarding"          "no"    "yes"
check_setting "Port"                   "22"    ""

local current_port
current_port=$(grep -iE "^\s*Port\s+" "$CONFIG" 2>/dev/null | tail -1 | awk '{print $2}')
[ -z "$current_port" ] && current_port=22

local active_sessions
active_sessions=$(ss -tnH 2>/dev/null | awk -v p=":$current_port" '$4 ~ p && $1 == "ESTAB"' | wc -l)
echo -e "    ${COLOR_GRAY}── Active SSH sessions: ${active_sessions}${COLOR_RESET}"