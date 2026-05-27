#!/bin/bash

stats() {
    local SUTD_DIR="$HOME/.sutd"
    
    echo ""
    echo "  ╭─ Shell statistics ─────────────────"
    echo "  │"
    
    local total_cmds
    total_cmds=$(history | wc -l)
    printf "  │  ${COLOR_WHITE}Total commands in history:${COLOR_RESET} %s\n" "$total_cmds"
    
    echo "  │"
    echo "  │  Top 10 commands:"
    history | awk '{$1=""; print substr($0,2)}' | awk '{print $1}' \
        | sort | uniq -c | sort -rn | head -10 \
        | while read count cmd; do
            printf "  │    %4d × %s\n" "$count" "$cmd"
        done
    
    if [ -f "$SUTD_DIR/data/last_commands.log" ]; then
        local logged
        logged=$(wc -l < "$SUTD_DIR/data/last_commands.log")
        echo "  │"
        printf "  │  Logged commands (last sessions): %s\n" "$logged"
    fi
    
    if [ -f "$SUTD_DIR/data/streak.dat" ]; then
        local streak max
        streak=$(awk -F= '/^streak=/ {print $2}' "$SUTD_DIR/data/streak.dat")
        max=$(awk -F= '/^max=/ {print $2}' "$SUTD_DIR/data/streak.dat")
        echo "  │"
        printf "  │  Current streak: %s days (record: %s)\n" "$streak" "$max"
    fi
    
    if [ -f "$SUTD_DIR/data/achievements.dat" ]; then
        local ach
        ach=$(wc -l < "$SUTD_DIR/data/achievements.dat")
        printf "  │  Achievements unlocked: %s\n" "$ach"
    fi
    
    echo "  │"
    echo "  ╰────────────────────────────────────"
}