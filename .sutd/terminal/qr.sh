#!/bin/bash

qr() {
    if [ $# -eq 0 ]; then
        cat << 'EOF'
  qr — generate QR code in terminal

  Usage:
    qr "<text>"
    qr -s "<text>"          small (compact)
    qr -f <file>            QR for file contents
    qr -u "<url>"           generate via online API (no install needed)

  Examples:
    qr "https://onlysq.ru"
    qr "wifi:T:WPA;S:MyNet;P:pass123;;"
EOF
        return
    fi
    
    local mode="big"
    local text=""
    local online=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -s|--small) mode="small"; shift ;;
            -f|--file)  text=$(cat "$2"); shift 2 ;;
            -u|--url|--online) online=1; shift ;;
            *)          text="$1"; shift ;;
        esac
    done
    
    [ -z "$text" ] && { echo "  empty input"; return 1; }
    
    if [ "$online" -eq 1 ]; then
        local encoded
        encoded=$(printf '%s' "$text" | python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))' 2>/dev/null)
        echo "  → https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encoded}"
        return
    fi
    
    if command -v qrencode &>/dev/null; then
        if [ "$mode" = "small" ]; then
            qrencode -t ANSIUTF8 -m 1 "$text"
        else
            qrencode -t ANSIUTF8 "$text"
        fi
    else
        echo -e "  \033[33m⚠\033[0m qrencode not installed"
        echo "  install:  sudo apt install qrencode"
        echo "  or use:   qr -u \"<text>\"  for online generation"
        return 1
    fi
}