#!/bin/bash

__HELPME_DIR="$HOME/.sutd/data/helpme"
mkdir -p "$__HELPME_DIR"

__helpme_seed() {
    [ -f "$__HELPME_DIR/aliases.md" ] && return
    
    cat > "$__HELPME_DIR/navigation.md" << 'EOF'
# Navigation

## Quick cd
- `..` — go up one dir
- `...` — go up two
- `....` — go up three

## Bookmarks
- `bookmark <name>` — save current dir
- `go <name>` — jump to bookmark
- `go` — list all bookmarks
- `unbookmark <name>` — remove

## Examples
    cd /var/www/api
    bookmark api
    cd /
    go api          # back to /var/www/api
EOF

    cat > "$__HELPME_DIR/aliases.md" << 'EOF'
# Alias Manager (al)

Save and run commands by name.

## Save
    al "systemctl restart nginx" rnginx

## Run
    al rnginx

## With arguments
    al "systemctl {1} {2}" sysctl
    sysctl restart nginx

## Manage
- `al` — list all
- `al <name> -e` — edit
- `al <name> -d` — delete
- `al -s docker` — search
EOF

    cat > "$__HELPME_DIR/services.md" << 'EOF'
# Service Manager (svc)

Interactive systemd service manager.

## Usage
    svc

Pick a service from list, then choose action:
start / stop / restart / status / enable / disable / logs

## Add services
Edit `~/.sutd/services.list` — one service per line.
EOF

    cat > "$__HELPME_DIR/notes.md" << 'EOF'
# Notes

## Add
    note "купить SSL для домена"

## List
    note

## Delete by number
    note -d 3

## Edit in $EDITOR
    note -e

## Clear all
    note -c
EOF

    cat > "$__HELPME_DIR/utils.md" << 'EOF'
# Utilities

- `extract <archive>` — unpack any archive
- `backup <file>` — copy with timestamp
- `bigfiles [n]` — top largest files
- `ports` — open listening ports
- `myip` — local + public IP
- `weather [city]` — weather
- `calc "<expr>"` — calculator
- `serve [-p port]` — quick HTTP server
- `peek <file.json>` — pretty JSON view
- `qr "<text>"` — QR code in terminal
EOF

    cat > "$__HELPME_DIR/chains.md" << 'EOF'
# Command Chains (chain)

Save sequences of commands as named pipelines.

## Create
    chain new deploy
    chain add deploy "git pull"
    chain add deploy "npm install"
    chain add deploy "pm2 restart api"

## Run
    chain run deploy                # all in sequence
    chain run deploy -c             # confirm each step

## Manage
- `chain ls` — list chains
- `chain show deploy` — show steps
- `chain rm deploy` — delete
- `chain edit deploy` — edit in $EDITOR
EOF

    cat > "$__HELPME_DIR/safety.md" << 'EOF'
# Safety & Recovery

## redo — re-run last command
    ls /etc
    redo /var               # ls /var
    redo s/etc/var/         # sed replace

## safe-rm
Dangerous rm requires confirmation:
    rm -rf /tmp/x           # asks yes/no
    rm -rf /etc             # asks to type 'yes'

## remember
    remember API_KEY=abc    # auto-export next session
    remember                # list all
    remember -d API_KEY     # forget
EOF
}

helpme() {
    __helpme_seed
    
    if [ $# -gt 0 ]; then
        case "$1" in
            -w|--web|serve)
                local port="${2:-${HELPME_PORT:-8765}}"
                __helpme_serve "$port"
                return
                ;;
            -l|--list)
                ls "$__HELPME_DIR"/*.md 2>/dev/null | xargs -n1 basename | sed 's/\.md$//'
                return
                ;;
            -h|--help)
                cat << 'EOF'
  helpme — interactive help system

  Usage:
    helpme              browse categories
    helpme <topic>      show specific topic
    helpme -l           list topics
    helpme -w [port]    serve over HTTP
    helpme -h           this help
EOF
                return
                ;;
            *)
                local f="$__HELPME_DIR/${1}.md"
                if [ -f "$f" ]; then
                    __helpme_render "$f"
                else
                    echo "no topic: $1"
                    echo "available:"
                    ls "$__HELPME_DIR"/*.md 2>/dev/null | xargs -n1 basename | sed 's/^/  /; s/\.md$//'
                fi
                return
                ;;
        esac
    fi
    
    while true; do
        clear
        echo -e "\033[38;5;208m"
        echo "  ┌─────────────────────────────────┐"
        echo "  │     Bashboard Help Center       │"
        echo "  └─────────────────────────────────┘"
        echo -e "\033[0m"
        
        local topics=()
        local i=1
        for f in "$__HELPME_DIR"/*.md; do
            [ -f "$f" ] || continue
            local name=$(basename "$f" .md)
            topics+=("$name")
            local title=$(head -1 "$f" | sed 's/^#\s*//')
            printf "  \033[90m%2d)\033[0m \033[37m%-15s\033[0m \033[90m— %s\033[0m\n" "$i" "$name" "$title"
            i=$((i+1))
        done
        echo ""
        echo -e "  \033[90mw) serve over HTTP    q) quit\033[0m"
        echo ""
        read -p "  Select: " choice
        
        case "$choice" in
            q|Q|"") clear; return ;;
            w|W) __helpme_serve "${HELPME_PORT:-8765}"; read -p "press enter..." _ ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#topics[@]}" ]; then
                    clear
                    __helpme_render "$__HELPME_DIR/${topics[$((choice-1))]}.md"
                    echo ""
                    read -p "  press enter to return..." _
                fi
                ;;
        esac
    done
}

__helpme_render() {
    local f="$1"
    while IFS= read -r line; do
        case "$line" in
            "# "*) echo -e "\033[38;5;208m${line#\# }\033[0m"; echo -e "\033[90m$(printf '%.s─' $(seq 1 $((${#line}+5))))\033[0m" ;;
            "## "*) echo -e "\n\033[37m▸ ${line#\#\# }\033[0m" ;;
            "    "*) echo -e "\033[38;5;75m${line}\033[0m" ;;
            "- "*) echo -e "  ${line}" ;;
            "") echo "" ;;
            *) echo "  $line" ;;
        esac
    done < "$f"
}

__helpme_md_to_html() {
    local infile="$1"
    awk '
        function escape(s) {
            gsub(/&/, "\\&", s)
            gsub(/</, "\\<",  s)
            gsub(/>/, "\\>",  s)
            return s
        }
        function inline_code(s,    out, i, c, in_code, ch) {
            out = ""
            in_code = 0
            for (i = 1; i <= length(s); i++) {
                ch = substr(s, i, 1)
                if (ch == "`") {
                    if (in_code) { out = out "</code>"; in_code = 0 }
                    else         { out = out "<code>";  in_code = 1 }
                } else {
                    out = out ch
                }
            }
            if (in_code) out = out "</code>"
            return out
        }
        BEGIN { in_pre = 0; in_ul = 0 }
        {
            line = $0
            esc  = escape(line)

            if (line ~ /^# /) {
                if (in_pre) { print "</pre>"; in_pre = 0 }
                if (in_ul)  { print "</ul>";  in_ul  = 0 }
                sub(/^# /, "", esc)
                print "<h1>" inline_code(esc) "</h1>"
                next
            }
            if (line ~ /^## /) {
                if (in_pre) { print "</pre>"; in_pre = 0 }
                if (in_ul)  { print "</ul>";  in_ul  = 0 }
                sub(/^## /, "", esc)
                print "<h2>" inline_code(esc) "</h2>"
                next
            }
            if (line ~ /^### /) {
                if (in_pre) { print "</pre>"; in_pre = 0 }
                if (in_ul)  { print "</ul>";  in_ul  = 0 }
                sub(/^### /, "", esc)
                print "<h3>" inline_code(esc) "</h3>"
                next
            }
            if (line ~ /^    /) {
                if (in_ul) { print "</ul>"; in_ul = 0 }
                if (!in_pre) { print "<pre>"; in_pre = 1 }
                sub(/^    /, "", esc)
                print esc
                next
            }
            if (line ~ /^- /) {
                if (in_pre) { print "</pre>"; in_pre = 0 }
                if (!in_ul) { print "<ul>"; in_ul = 1 }
                sub(/^- /, "", esc)
                print "<li>" inline_code(esc) "</li>"
                next
            }
            if (line == "") {
                if (in_pre) { print "</pre>"; in_pre = 0 }
                if (in_ul)  { print "</ul>";  in_ul  = 0 }
                next
            }
            if (in_pre) { print "</pre>"; in_pre = 0 }
            if (in_ul)  { print "</ul>";  in_ul  = 0 }
            print "<p>" inline_code(esc) "</p>"
        }
        END {
            if (in_pre) print "</pre>"
            if (in_ul)  print "</ul>"
        }
    ' "$infile"
}

__helpme_serve() {
    [ -f "$HOME/.sutd/info.conf" ] && source "$HOME/.sutd/info.conf"
    
    local port="${1:-${HELPME_PORT:-8765}}"
    local bind="${HELPME_BIND:-127.0.0.1}"
    local tmp
    tmp=$(mktemp -d)
    
    cat > "$tmp/index.html" << 'HTML_HEAD'
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SUTD Help Center</title>
<style>
* { box-sizing: border-box; }
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    background: #1a1a1a;
    color: #ddd;
    max-width: 920px;
    margin: 0 auto;
    padding: 2em 1.5em;
    line-height: 1.65;
}
h1 { color: #ff8c30; border-bottom: 1px solid #444; padding-bottom: .3em; margin-top: 2em; }
h2 { color: #fff; margin-top: 1.5em; }
h3 { color: #7fc7ff; }
pre {
    background: #0f0f0f;
    color: #7fc7ff;
    padding: 1em;
    border-radius: 6px;
    overflow-x: auto;
    border-left: 3px solid #ff8c30;
    white-space: pre;
}
code {
    background: #0f0f0f;
    color: #7fc7ff;
    padding: .15em .4em;
    border-radius: 3px;
    font-family: "JetBrains Mono", Menlo, Consolas, monospace;
    font-size: .9em;
}
pre code { background: transparent; padding: 0; }
a { color: #ff8c30; text-decoration: none; }
a:hover { text-decoration: underline; }
.nav {
    display: flex; gap: .6em; flex-wrap: wrap;
    margin: 1em 0 2em; padding: 1em;
    background: #222; border-radius: 6px;
    position: sticky; top: 0; z-index: 10;
}
.nav a { padding: .35em .9em; background: #333; border-radius: 4px; transition: background .15s; }
.nav a:hover { background: #444; text-decoration: none; }
ul li { margin: .3em 0; }
.header { text-align: center; padding: 1em 0; }
.header .logo { color: #ff8c30; font-family: monospace; white-space: pre; font-size: .7em; }
.footer { margin-top: 4em; padding-top: 1em; border-top: 1px solid #333; color: #666; font-size: .9em; text-align: center; }
</style>
</head><body>
<div class="header">
<div class="logo">  ____        _       _____       
 / __ \      | |     / ____|      
| |  | |_ __ | |_   | (___   __ _ 
| |  | | '_ \| | | | |\___ \ / _` |
| |__| | | | | | |_| |____) | (_| |
 \____/|_| |_|_|\__, |_____/ \__, |
                 __/ |          | |
                |___/           |_|</div>
<h1 style="border:none">SUTD Help Center</h1>
</div>
<div class="nav">
HTML_HEAD
    
    for f in "$__HELPME_DIR"/*.md; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .md)
        echo "<a href=\"#${name}\">${name}</a>" >> "$tmp/index.html"
    done
    
    echo "</div>" >> "$tmp/index.html"
    
    for f in "$__HELPME_DIR"/*.md; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .md)
        echo "<section id=\"${name}\">" >> "$tmp/index.html"
        __helpme_md_to_html "$f" >> "$tmp/index.html"
        echo "</section>" >> "$tmp/index.html"
    done
    
    cat >> "$tmp/index.html" << HTML_FOOT
<div class="footer">
Served from $(hostname) at $(date '+%Y-%m-%d %H:%M') • Bashboard
</div>
</body></html>
HTML_FOOT
    
    echo "  → http://${bind}:${port}/"
    if [ "$bind" = "0.0.0.0" ]; then
        local ext
        ext=$(hostname -I 2>/dev/null | awk '{print $1}')
        [ -n "$ext" ] && echo "  → http://${ext}:${port}/"
    fi
    echo "  Ctrl+C to stop"
    
    (cd "$tmp" && python3 -m http.server "$port" --bind "$bind" 2>/dev/null)
    
    rm -rf "$tmp"
}

alias '?'='helpme'