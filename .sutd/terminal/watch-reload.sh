#!/bin/bash

watch-reload() {
    if [ $# -lt 2 ]; then
        cat << 'EOF'
  watch-reload — re-run command on file change

  Usage:
    watch-reload <file-or-dir> "<command>"
    watch-reload <file-or-dir> "<command>" --bg

  Examples:
    watch-reload nginx.conf "sudo nginx -s reload"
    watch-reload src/ "npm run build"
    watch-reload . "go build && ./app" --bg
EOF
        return
    fi
    
    local target="$1"; shift
    local cmd="$1"; shift
    local bg=0
    
    for arg in "$@"; do
        [ "$arg" = "--bg" ] && bg=1
    done
    
    if ! command -v inotifywait &>/dev/null; then
        echo -e "  \033[31m✗\033[0m inotifywait not installed"
        echo "  install with: sudo apt install inotify-tools"
        return 1
    fi
    
    [ ! -e "$target" ] && { echo "  no such file/dir: $target"; return 1; }
    
    if [ "$bg" -eq 1 ]; then
        local log="$HOME/.sutd/data/watch-$(echo "$target" | md5sum | cut -c1-8).log"
        nohup bash -c "
            while inotifywait -e modify,create,delete,move -r '$target' &>/dev/null; do
                echo \"[\$(date '+%H:%M:%S')] change detected\" >> '$log'
                eval '$cmd' >> '$log' 2>&1
            done
        " &>/dev/null &
        local pid=$!
        echo -e "  \033[32m✓\033[0m watching in background (pid $pid)"
        echo -e "  log: $log"
        echo -e "  stop with: kill $pid"
        return
    fi
    
    echo -e "  \033[37mwatching:\033[0m $target"
    echo -e "  \033[37mcommand:\033[0m  $cmd"
    echo -e "  \033[90m(Ctrl+C to stop)\033[0m"
    echo ""
    
    while true; do
        inotifywait -qq -e modify,create,delete,move -r "$target" 2>/dev/null
        echo -e "  \033[38;5;208m[$(date '+%H:%M:%S')]\033[0m change detected — running..."
        eval "$cmd"
        echo ""
    done
}