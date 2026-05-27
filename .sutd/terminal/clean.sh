#!/bin/bash

# :helpme:
# title: System Cleaner
# desc: Free up disk space by cleaning caches, logs, temp files
# category: system
# usage:
#   clean                   interactive analyzer with confirmations
#   clean apt               apt cache + autoremove
#   clean docker            docker prune (dangling)
#   clean docker-deep       docker prune + unused images + volumes
#   clean logs              old logs in /var/log
#   clean journal           journalctl vacuum
#   clean tmp               /tmp and /var/tmp
#   clean snap              old snap revisions
#   clean thumbnails        thumbnail caches
#   clean trash             ~/.local/share/Trash
#   clean --dry             show what would be cleaned, do nothing
#   clean -h                this help
# examples:
#   clean
#   clean apt
#   clean docker-deep
#   clean --dry
# :endhelpme:

__clean_dry=0

clean() {
    __clean_dry=0
    
    local targets=()
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry|--dry-run) __clean_dry=1; shift ;;
            -h|--help)
                cat << 'EOF'
  clean — free up disk space

  clean                   interactive analyzer
  clean apt               apt cache + autoremove
  clean docker            docker prune (dangling only)
  clean docker-deep       docker prune + unused images + volumes
  clean logs              compress/delete old logs in /var/log
  clean journal           vacuum systemd journal
  clean tmp               clean /tmp and /var/tmp
  clean snap              remove old snap revisions
  clean thumbnails        clear thumbnail cache
  clean trash             empty trash
  clean --dry             dry-run mode (show, don't delete)
EOF
                return
                ;;
            *) targets+=("$1"); shift ;;
        esac
    done
    
    if [ ${#targets[@]} -eq 0 ]; then
        __clean_interactive
        return
    fi
    
    for t in "${targets[@]}"; do
        case "$t" in
            apt)         __clean_apt ;;
            docker)      __clean_docker shallow ;;
            docker-deep) __clean_docker deep ;;
            logs)        __clean_logs ;;
            journal)     __clean_journal ;;
            tmp)         __clean_tmp ;;
            snap)        __clean_snap ;;
            thumbnails)  __clean_thumbnails ;;
            trash)       __clean_trash ;;
            *)           echo "  unknown: $t" ;;
        esac
    done
}

__clean_run() {
    local desc="$1"
    shift
    
    if [ "$__clean_dry" = "1" ]; then
        echo -e "  \033[90m[dry]\033[0m $desc"
        echo -e "  \033[90m      would run: $*\033[0m"
        return 0
    fi
    
    echo -e "  \033[90m→\033[0m $desc"
    "$@"
}

__clean_size_before() {
    local path="$1"
    [ -e "$path" ] && du -sb "$path" 2>/dev/null | awk '{print $1}'
}

__clean_human() {
    local bytes="$1"
    [ -z "$bytes" ] && { echo "0B"; return; }
    awk -v b="$bytes" 'BEGIN {
        if (b >= 1073741824) printf "%.1f GB", b/1073741824
        else if (b >= 1048576) printf "%.1f MB", b/1048576
        else if (b >= 1024) printf "%.1f KB", b/1024
        else printf "%d B", b
    }'
}

__clean_apt() {
    if ! command -v apt-get &>/dev/null; then
        echo "  apt not available"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ apt cleanup\033[0m"
    
    local before=$(__clean_size_before /var/cache/apt)
    
    __clean_run "apt-get clean (cache)" sudo apt-get clean
    __clean_run "apt-get autoremove --purge" sudo apt-get autoremove --purge -y
    __clean_run "apt-get autoclean" sudo apt-get autoclean -y
    
    local after=$(__clean_size_before /var/cache/apt)
    
    if [ "$__clean_dry" = "0" ] && [ -n "$before" ] && [ -n "$after" ]; then
        local saved=$((before - after))
        echo -e "  \033[32m✓\033[0m freed: $(__clean_human $saved)"
    fi
}

__clean_docker() {
    local mode="$1"
    
    if ! command -v docker &>/dev/null; then
        echo "  docker not installed"
        return
    fi
    
    if ! docker ps -q &>/dev/null; then
        echo "  docker daemon not running"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ docker cleanup ($mode)\033[0m"
    
    if [ "$mode" = "deep" ]; then
        __clean_run "remove ALL unused images + volumes + networks" docker system prune -a --volumes -f
    else
        __clean_run "remove dangling images" docker image prune -f
        __clean_run "remove stopped containers" docker container prune -f
        __clean_run "remove unused networks" docker network prune -f
    fi
}

__clean_logs() {
    echo -e "\n  \033[38;5;208m▸ log cleanup\033[0m"
    
    local old_logs=$(sudo find /var/log -type f $ -name "*.gz" -o -name "*.1" -o -name "*.old" $ -mtime +30 2>/dev/null)
    
    if [ -z "$old_logs" ]; then
        echo "  nothing to clean (no logs older than 30 days)"
        return
    fi
    
    local count=$(echo "$old_logs" | wc -l)
    local total_size=$(echo "$old_logs" | xargs -I {} du -b "{}" 2>/dev/null | awk '{s+=$1} END {print s}')
    
    echo -e "  \033[37mwould remove:\033[0m $count files, $(__clean_human $total_size)"
    
    if [ "$__clean_dry" = "1" ]; then
        echo "$old_logs" | head -10 | while read f; do
            echo -e "  \033[90m[dry]\033[0m would rm $f"
        done
        return
    fi
    
    read -p "  Proceed? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
    
    echo "$old_logs" | xargs sudo rm -f
    echo -e "  \033[32m✓\033[0m freed: $(__clean_human $total_size)"
}

__clean_journal() {
    if ! command -v journalctl &>/dev/null; then
        echo "  journalctl not available"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ journal vacuum\033[0m"
    
    local current_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[MGB]+' | head -1)
    echo -e "  \033[37mcurrent journal size:\033[0m $current_size"
    
    __clean_run "vacuum journal to last 7 days" sudo journalctl --vacuum-time=7d
    __clean_run "vacuum journal to 500M max" sudo journalctl --vacuum-size=500M
}

__clean_tmp() {
    echo -e "\n  \033[38;5;208m▸ /tmp + /var/tmp cleanup\033[0m"
    
    local tmp_old=$(find /tmp -type f -mtime +7 2>/dev/null | wc -l)
    local var_tmp_old=$(find /var/tmp -type f -mtime +30 2>/dev/null | wc -l)
    
    echo -e "  \033[37mfound:\033[0m /tmp: $tmp_old files (>7d), /var/tmp: $var_tmp_old files (>30d)"
    
    __clean_run "/tmp files older than 7 days" sudo find /tmp -type f -mtime +7 -delete
    __clean_run "/var/tmp files older than 30 days" sudo find /var/tmp -type f -mtime +30 -delete
}

__clean_snap() {
    if ! command -v snap &>/dev/null; then
        echo "  snap not installed"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ snap old revisions\033[0m"
    
    local disabled=$(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}')
    
    if [ -z "$disabled" ]; then
        echo "  no disabled snap revisions"
        return
    fi
    
    echo "$disabled" | while read name rev; do
        __clean_run "remove $name rev $rev" sudo snap remove "$name" --revision="$rev"
    done
}

__clean_thumbnails() {
    echo -e "\n  \033[38;5;208m▸ thumbnail caches\033[0m"
    
    local thumb_dir="$HOME/.cache/thumbnails"
    if [ -d "$thumb_dir" ]; then
        local size=$(du -sb "$thumb_dir" 2>/dev/null | awk '{print $1}')
        echo -e "  \033[37msize:\033[0m $(__clean_human $size)"
        __clean_run "remove $thumb_dir" rm -rf "$thumb_dir"/*
    else
        echo "  no thumbnail cache found"
    fi
}

__clean_trash() {
    local trash_dir="$HOME/.local/share/Trash"
    
    if [ ! -d "$trash_dir" ]; then
        echo "  no trash directory"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ trash\033[0m"
    
    local size=$(du -sb "$trash_dir" 2>/dev/null | awk '{print $1}')
    local count=$(find "$trash_dir" -type f 2>/dev/null | wc -l)
    
    echo -e "  \033[37msize:\033[0m $(__clean_human $size), $count files"
    
    __clean_run "empty trash" rm -rf "$trash_dir"/files/* "$trash_dir"/info/*
}

__clean_interactive() {
    echo -e "  \033[38;5;208m▸ Disk space analyzer\033[0m"
    echo ""
    
    df -h / | awk 'NR==2 {printf "  root: %s used of %s (%s)\n", $3, $2, $5}'
    echo ""
    
    echo -e "  \033[37mLargest cleanup targets:\033[0m"
    
    declare -A sizes
    
    if [ -d /var/cache/apt ]; then
        sizes[apt]=$(__clean_size_before /var/cache/apt)
    fi
    if command -v docker &>/dev/null && docker ps -q &>/dev/null; then
        sizes[docker]=$(docker system df 2>/dev/null | awk '/^Images/ {print $4}' | grep -oE '[0-9.]+' | head -1