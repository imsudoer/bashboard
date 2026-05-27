#!/bin/bash

SUTD_DIR="$HOME/.sutd"

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'

mkcd() {
    mkdir -p "$1" && cd "$1"
}

bookmark() {
    local name="$1"
    [ -z "$name" ] && { echo "usage: bookmark <name>"; return 1; }
    mkdir -p "$SUTD_DIR/data"
    sed -i "/^${name}=/d" "$SUTD_DIR/data/bookmarks" 2>/dev/null
    echo "${name}=$(pwd)" >> "$SUTD_DIR/data/bookmarks"
    echo "✓ bookmarked '$name' → $(pwd)"
}

go() {
    if [ -z "$1" ]; then
        echo "Bookmarks:"
        column -t -s= "$SUTD_DIR/data/bookmarks" 2>/dev/null
        return
    fi
    local path
    path=$(grep "^$1=" "$SUTD_DIR/data/bookmarks" 2>/dev/null | cut -d= -f2-)
    [ -z "$path" ] && { echo "no such bookmark: $1"; return 1; }
    cd "$path"
}

unbookmark() {
    sed -i "/^$1=/d" "$SUTD_DIR/data/bookmarks"
    echo "✗ removed bookmark '$1'"
}

hgrep() {
    history | grep -i --color=auto "$1"
}

hrun() {
    local cmd
    cmd=$(history | grep -i "$1" | tail -1 | sed 's/^[ 0-9]*//')
    echo "→ $cmd"
    eval "$cmd"
}

note() {
    local file="$SUTD_DIR/data/notes.txt"
    if [ -z "$1" ]; then
        if [ -s "$file" ]; then
            cat -n "$file"
        else
            echo "(no notes)"
        fi
        return
    fi
    case "$1" in
        -d|--delete)
            sed -i "${2}d" "$file"
            echo "✗ deleted note #$2"
            ;;
        -c|--clear)
            > "$file"
            echo "✗ all notes cleared"
            ;;
        -e|--edit)
            ${EDITOR:-nano} "$file"
            ;;
        *)
            echo "[$(date '+%Y-%m-%d %H:%M')] $*" >> "$file"
            echo "✓ note added"
            ;;
    esac
}

extract() {
    [ -f "$1" ] || { echo "no such file: $1"; return 1; }
    case "$1" in
        *.tar.bz2) tar xjf "$1" ;;
        *.tar.gz)  tar xzf "$1" ;;
        *.tar.xz)  tar xJf "$1" ;;
        *.tar)     tar xf  "$1" ;;
        *.tbz2)    tar xjf "$1" ;;
        *.tgz)     tar xzf "$1" ;;
        *.bz2)     bunzip2 "$1" ;;
        *.gz)      gunzip "$1" ;;
        *.zip)     unzip "$1" ;;
        *.rar)     unrar x "$1" ;;
        *.7z)      7z x "$1" ;;
        *.Z)       uncompress "$1" ;;
        *)         echo "unknown archive: $1" ;;
    esac
}

backup() {
    local f="$1"
    [ -f "$f" ] || { echo "no such file: $f"; return 1; }
    cp "$f" "${f}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "✓ backed up $f"
}

bigfiles() {
    local n="${1:-10}"
    du -ah . 2>/dev/null | sort -hr | head -n "$n"
}

ports() {
    sudo ss -tlnp 2>/dev/null || ss -tln
}

myip() {
    echo "Local : $(hostname -I | awk '{print $1}')"
    echo "Public: $(curl -s --max-time 3 ifconfig.me)"
}

weather() {
    curl -s "wttr.in/${1:-Moscow}?format=3"
}

calc() {
    echo "$*" | bc -l
}

__sutd_log_cmd() {
    local last
    last=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')
    [ -z "$last" ] && return
    case "$last" in
        ""|"exit"|"clear"|"ls"|"ll"|"la"|"l") return ;;
    esac
    mkdir -p "$SUTD_DIR/data"
    echo "$(date '+%Y-%m-%d %H:%M')|$last" >> "$SUTD_DIR/data/last_commands.log"
    tail -n 100 "$SUTD_DIR/data/last_commands.log" > "$SUTD_DIR/data/last_commands.log.tmp" \
        && mv "$SUTD_DIR/data/last_commands.log.tmp" "$SUTD_DIR/data/last_commands.log"
}

if [ -z "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="__sutd_log_cmd"
else
    case ";$PROMPT_COMMAND;" in
        *";__sutd_log_cmd;"*) ;;
        *) PROMPT_COMMAND="$PROMPT_COMMAND;__sutd_log_cmd" ;;
    esac
fi