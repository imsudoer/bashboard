#!/bin/bash

menu() {
    local mode="${INTERFACE_MODE:-1}"
    local force=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--menu)    force="1"; shift ;;
            -t|--tui)     force="2"; shift ;;
            -p|--plain)   force="0"; shift ;;
            -h|--help)
                cat << 'EOF'
  menu — re-open the Bashboard interface

  Usage:
    menu                open in default mode (from INTERFACE_MODE)
    menu -m, --menu     force slides menu
    menu -t, --tui      force full TUI
    menu -p, --plain    force plain MOTD dump
    menu -h             this help

  The default mode is read from ~/.sutd/info.conf (INTERFACE_MODE).
EOF
                return 0
                ;;
            *)
                echo "  unknown option: $1"
                echo "  try: menu -h"
                return 1
                ;;
        esac
    done
    
    [ -n "$force" ] && mode="$force"
    
    case "$mode" in
        0)
            if [ -x "$HOME/.sutd/motd.sh" ]; then
                INTERFACE_MODE=0 "$HOME/.sutd/motd.sh"
            else
                echo "  motd.sh not found at $HOME/.sutd/motd.sh"
                return 1
            fi
            ;;
        1)
            if [ -x "$HOME/.sutd/menu.sh" ]; then
                "$HOME/.sutd/menu.sh"
            else
                echo "  menu.sh not found at $HOME/.sutd/menu.sh"
                return 1
            fi
            ;;
        2)
            if [ -x "$HOME/.sutd/tui.sh" ]; then
                "$HOME/.sutd/tui.sh"
            else
                echo "  tui.sh not found at $HOME/.sutd/tui.sh"
                return 1
            fi
            ;;
        *)
            echo "  invalid mode: $mode (expected 0, 1, or 2)"
            return 1
            ;;
    esac
}

_menu_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "-m --menu -t --tui -p --plain -h --help" -- "$cur") )
}
complete -F _menu_complete menu

alias mm='menu'