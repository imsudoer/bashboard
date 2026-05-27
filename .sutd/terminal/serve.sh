#!/bin/bash

serve() {
    local ip="0.0.0.0"
    local port="8000"
    local dir="."
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--ip)   ip="$2"; shift 2 ;;
            -p|--port) port="$2"; shift 2 ;;
            -d|--dir)  dir="$2"; shift 2 ;;
            -h|--help)
                cat << 'EOF'
serve — quick HTTP server

Usage: serve [options]
  -i, --ip <addr>     bind address (default: 0.0.0.0)
  -p, --port <port>   port (default: 8000)
  -d, --dir <path>    directory to serve (default: .)
  -h, --help          show this help

Examples:
  serve
  serve -p 9000
  serve -i 127.0.0.1 -p 8080 -d /var/www
EOF
                return 0
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then port="$1"
                else ip="$1"; fi
                shift
                ;;
        esac
    done
    
    if ! command -v python3 &>/dev/null; then
        echo "python3 not installed"; return 1
    fi
    
    echo "→ serving '$dir' on http://${ip}:${port}"
    echo "  external: http://$(hostname -I | awk '{print $1}'):${port}"
    echo "  press Ctrl+C to stop"
    (cd "$dir" && python3 -m http.server "$port" --bind "$ip")
}