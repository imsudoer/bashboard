#!/bin/bash

# :helpme:
# title: System Cleaner
# desc: Free up disk space by cleaning caches, logs, temp files
# category: system
# usage:
#   clean                       interactive analyzer with selectable targets
#   clean apt                   apt cache + autoremove
#   clean docker                docker prune (dangling only)
#   clean docker-deep           docker prune + unused images + volumes
#   clean logs                  old logs in /var/log (older than 30 days)
#   clean journal               vacuum systemd journal
#   clean tmp                   /tmp and /var/tmp old files
#   clean snap                  remove disabled snap revisions
#   clean thumbnails            thumbnail caches
#   clean trash                 empty ~/.local/share/Trash
#   clean all                   run everything safe (no docker-deep)
#   clean --dry                 show what would be cleaned, do nothing
#   clean -h                    this help
# examples:
#   clean
#   clean apt
#   clean docker-deep
#   clean --dry all
# :endhelpme:

__clean_dry=0

clean() {
    __clean_dry=0
    local targets=()
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry|--dry-run|-n) __clean_dry=1; shift ;;
            -h|--help)
                cat << 'EOF'
  clean — free up disk space

  clean                   interactive analyzer
  clean apt               apt cache + autoremove
  clean docker            docker prune (dangling only)
  clean docker-deep       docker prune + unused images + volumes
  clean logs              old logs in /var/log
  clean journal           vacuum systemd journal
  clean tmp               /tmp + /var/tmp
  clean snap              old snap revisions
  clean thumbnails        thumbnail caches
  clean trash             ~/.local/share/Trash
  clean all               run everything safe
  clean --dry             dry-run mode
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
            all)
                __clean_apt
                __clean_docker shallow
                __clean_logs
                __clean_journal
                __clean_tmp
                __clean_snap
                __clean_thumbnails
                __clean_trash
                ;;
            *) echo "  unknown target: $t" ;;
        esac
    done
    
    __clean_show_freed
}

__clean_size_of() {
    local path="$1"
    [ ! -e "$path" ] && { echo "0"; return; }
    du -sb "$path" 2>/dev/null | awk '{print $1+0}'
}

__clean_human() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1073741824) printf "%.1f GB", b/1073741824
        else if (b >= 1048576) printf "%.1f MB", b/1048576
        else if (b >= 1024) printf "%.0f KB", b/1024
        else printf "%d B", b
    }'
}

__clean_disk_free() {
    df -B1 / 2>/dev/null | awk 'NR==2 {print $4}'
}

__clean_run() {
    local desc="$1"
    shift
    
    if [ "$__clean_dry" = "1" ]; then
        echo -e "  \033[90m[dry]\033[0m $desc"
        echo -e "  \033[90m      $*\033[0m"
        return 0
    fi
    
    echo -e "  \033[90m→\033[0m $desc"
    "$@" 2>&1 | tail -3 | sed 's/^/    /'
}

__clean_apt() {
    if ! command -v apt-get &>/dev/null; then
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ apt\033[0m"
    
    local before=$(__clean_size_of /var/cache/apt)
    
    __clean_run "apt-get clean" sudo apt-get clean
    __clean_run "apt-get autoremove --purge" sudo apt-get autoremove --purge -y
    __clean_run "apt-get autoclean" sudo apt-get autoclean -y
    
    if [ "$__clean_dry" = "0" ]; then
        local after=$(__clean_size_of /var/cache/apt)
        local saved=$((before - after))
        [ "$saved" -gt 0 ] && echo -e "  \033[32m✓\033[0m freed: $(__clean_human $saved)"
    fi
}

__clean_docker() {
    local mode="$1"
    
    if ! command -v docker &>/dev/null; then
        return
    fi
    
    if ! docker ps -q &>/dev/null 2>&1; then
        echo -e "\n  \033[38;5;208m▸ docker\033[0m"
        echo "    daemon not reachable, skipping"
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ docker ($mode)\033[0m"
    
    if [ "$__clean_dry" = "1" ]; then
        echo -e "  \033[90m[dry]\033[0m current docker disk usage:"
        docker system df 2>/dev/null | sed 's/^/    /'
        return
    fi
    
    if [ "$mode" = "deep" ]; then
        echo -e "  \033[31m⚠ This removes ALL unused images and volumes\033[0m"
        read -p "  Type 'yes' to confirm: " ok
        [ "$ok" != "yes" ] && { echo "  cancelled"; return; }
        __clean_run "system prune (deep)" docker system prune -a --volumes -f
    else
        __clean_run "image prune" docker image prune -f
        __clean_run "container prune" docker container prune -f
        __clean_run "network prune" docker network prune -f
        __clean_run "builder cache prune" docker builder prune -f
    fi
}

__clean_logs() {
    echo -e "\n  \033[38;5;208m▸ /var/log\033[0m"
    
    local sudo_cmd="sudo"
    [ "$(id -u)" -eq 0 ] && sudo_cmd=""
    
    local old=$($sudo_cmd find /var/log -type f $ -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" -o -name "*.[0-9].*" $ -mtime +30 2>/dev/null)
    
    if [ -z "$old" ]; then
        echo "    nothing to clean"
        return
    fi
    
    local count=$(echo "$old" | wc -l)
    local total=0
    while IFS= read -r f; do
        local s=$($sudo_cmd stat -c '%s' "$f" 2>/dev/null)
        total=$((total + ${s:-0}))
    done <<< "$old"
    
    echo -e "  \033[37mfound:\033[0m $count files, $(__clean_human $total)"
    
    if [ "$__clean_dry" = "1" ]; then
        echo "$old" | head -5 | while read f; do
            echo -e "  \033[90m[dry]\033[0m would rm $f"
        done
        [ "$count" -gt 5 ] && echo -e "  \033[90m[dry]\033[0m ... and $((count - 5)) more"
        return
    fi
    
    read -p "  Proceed? [y/N]: " ok
    [[ ! "$ok" =~ ^[yY]$ ]] && { echo "  cancelled"; return; }
    
    echo "$old" | xargs $sudo_cmd rm -f
    echo -e "  \033[32m✓\033[0m freed: $(__clean_human $total)"
}

__clean_journal() {
    if ! command -v journalctl &>/dev/null; then
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ journal\033[0m"
    
    local current=$(journalctl --disk-usage 2>/dev/null | grep -oE 'take up [^ ]+' | awk '{print $3}')
    echo -e "  \033[37mcurrent:\033[0m $current"
    
    __clean_run "vacuum to last 7 days" sudo journalctl --vacuum-time=7d
    __clean_run "cap at 500M" sudo journalctl --vacuum-size=500M
}

__clean_tmp() {
    echo -e "\n  \033[38;5;208m▸ /tmp + /var/tmp\033[0m"
    
    local sudo_cmd="sudo"
    [ "$(id -u)" -eq 0 ] && sudo_cmd=""
    
    local tmp_old_count=$($sudo_cmd find /tmp -type f -mtime +7 2>/dev/null | wc -l)
    local var_old_count=$($sudo_cmd find /var/tmp -type f -mtime +30 2>/dev/null | wc -l)
    
    echo -e "  \033[37m/tmp:\033[0m $tmp_old_count files older than 7d"
    echo -e "  \033[37m/var/tmp:\033[0m $var_old_count files older than 30d"
    
    if [ "$tmp_old_count" -eq 0 ] && [ "$var_old_count" -eq 0 ]; then
        echo "    nothing to clean"
        return
    fi
    
    __clean_run "delete /tmp files >7 days" $sudo_cmd find /tmp -type f -mtime +7 -delete
    __clean_run "delete /var/tmp files >30 days" $sudo_cmd find /var/tmp -type f -mtime +30 -delete
    __clean_run "remove empty dirs in /tmp" $sudo_cmd find /tmp -type d -empty -mindepth 1 -delete
}

__clean_snap() {
    if ! command -v snap &>/dev/null; then
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ snap\033[0m"
    
    local disabled=$(snap list --all 2>/dev/null | awk '/disabled/{print $1"|"$3}')
    
    if [ -z "$disabled" ]; then
        echo "    no disabled revisions"
        return
    fi
    
    local count=$(echo "$disabled" | wc -l)
    echo -e "  \033[37mfound:\033[0m $count disabled revision(s)"
    
    if [ "$__clean_dry" = "1" ]; then
        echo "$disabled" | while IFS='|' read name rev; do
            echo -e "  \033[90m[dry]\033[0m would remove $name rev $rev"
        done
        return
    fi
    
    echo "$disabled" | while IFS='|' read name rev; do
        echo -e "  \033[90m→\033[0m removing $name rev $rev"
        sudo snap remove "$name" --revision="$rev" 2>&1 | tail -2 | sed 's/^/    /'
    done
}

__clean_thumbnails() {
    local thumb="$HOME/.cache/thumbnails"
    
    if [ ! -d "$thumb" ]; then
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ thumbnails\033[0m"
    
    local size=$(__clean_size_of "$thumb")
    
    if [ "$size" -eq 0 ]; then
        echo "    already empty"
        return
    fi
    
    echo -e "  \033[37msize:\033[0m $(__clean_human $size)"
    
    __clean_run "clear $thumb" find "$thumb" -mindepth 1 -delete
}

__clean_trash() {
    local trash="$HOME/.local/share/Trash"
    
    if [ ! -d "$trash" ]; then
        return
    fi
    
    echo -e "\n  \033[38;5;208m▸ trash\033[0m"
    
    local size=$(__clean_size_of "$trash")
    local count=$(find "$trash" -type f 2>/dev/null | wc -l)
    
    if [ "$size" -eq 0 ]; then
        echo "    already empty"
        return
    fi
    
    echo -e "  \033[37msize:\033[0m $(__clean_human $size), $count files"
    
    __clean_run "empty files/" rm -rf "$trash/files/"
    __clean_run "empty info/" rm -rf "$trash/info/"
    mkdir -p "$trash/files" "$trash/info"
}

__clean_show_freed() {
    [ "$__clean_dry" = "1" ] && return
    
    [ -z "$__CLEAN_DISK_BEFORE" ] && return
    
    local after=$(__clean_disk_free)
    local diff=$((after - __CLEAN_DISK_BEFORE))
    
    echo ""
    if [ "$diff" -gt 0 ]; then
        echo -e "  \033[32m✓\033[0m total freed: $(__clean_human $diff)"
    elif [ "$diff" -lt 0 ]; then
        echo -e "  \033[33m⚠\033[0m disk usage went up (new files written during cleanup?)"
    else
        echo -e "  \033[90m└\033[0m no measurable change"
    fi
    
    unset __CLEAN_DISK_BEFORE
}

__clean_interactive() {
    __CLEAN_DISK_BEFORE=$(__clean_disk_free)
    
    echo -e "  \033[38;5;208m▸ Disk space analyzer\033[0m"
    echo ""
    
    df -h / 2>/dev/null | awk 'NR==2 {
        printf "  \033[37mdisk /:\033[0m %s used / %s total \033[90m(%s used)\033[0m\n", $3, $2, $5
    }'
    echo ""
    
    local apt_size docker_size journal_size logs_size tmp_size snap_size thumb_size trash_size
    
    if command -v apt-get &>/dev/null; then
        apt_size=$(__clean_size_of /var/cache/apt)
    else
        apt_size=0
    fi
    
    if command -v docker &>/dev/null && docker ps -q &>/dev/null 2>&1; then
        local raw=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1)
        docker_size=0
    else
        docker_size=0
    fi
    
    if command -v journalctl &>/dev/null; then
        journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGT]?' | head -1)
        [ -z "$journal_size" ] && journal_size="?"
    else
        journal_size="?"
    fi
    
    local sudo_cmd="sudo"
    [ "$(id -u)" -eq 0 ] && sudo_cmd=""
    
    local logs_count=$($sudo_cmd find /var/log -type f $ -name "*.gz" -o -name "*.[0-9]" -o -name "*.old" $ -mtime +30 2>/dev/null | wc -l)
    
    local tmp_count=$($sudo_cmd find /tmp -type f -mtime +7 2>/dev/null | wc -l)
    local var_tmp_count=$($sudo_cmd find /var/tmp -type f -mtime +30 2>/dev/null | wc -l)
    tmp_size=$((tmp_count + var_tmp_count))
    
    if command -v snap &>/dev/null; then
        snap_size=$(snap list --all 2>/dev/null | awk '/disabled/' | wc -l)
    else
        snap_size=0
    fi
    
    thumb_size=$(__clean_size_of "$HOME/.cache/thumbnails")
    trash_size=$(__clean_size_of "$HOME/.local/share/Trash")
    
    echo -e "  \033[37mAvailable targets:\033[0m"
    
    local opts=()
    local labels=()
    
    if [ "$apt_size" -gt 0 ]; then
        opts+=("apt")
        labels+=("apt cache         $(__clean_human $apt_size)")
    fi
    
    if command -v docker &>/dev/null && docker ps -q &>/dev/null 2>&1; then
        opts+=("docker")
        labels+=("docker            prune dangling")
        opts+=("docker-deep")
        labels+=("docker-deep       remove ALL unused images + volumes")
    fi
    
    opts+=("logs")
    labels+=("logs              $logs_count old log files in /var/log")
    
    if command -v journalctl &>/dev/null; then
        opts+=("journal")
        labels+=("journal           current size: $journal_size")
    fi
    
    if [ "$tmp_size" -gt 0 ]; then
        opts+=("tmp")
        labels+=("tmp               $tmp_count files in /tmp, $var_tmp_count in /var/tmp")
    fi
    
    if [ "$snap_size" -gt 0 ]; then
        opts+=("snap")
        labels+=("snap              $snap_size disabled revisions")
    fi
    
    if [ "$thumb_size" -gt 0 ]; then
        opts+=("thumbnails")
        labels+=("thumbnails        $(__clean_human $thumb_size)")
    fi
    
    if [ "$trash_size" -gt 0 ]; then
        opts+=("trash")
        labels+=("trash             $(__clean_human $trash_size)")
    fi
    
    if [ ${#opts[@]} -eq 0 ]; then
        echo "    nothing significant to clean"
        return
    fi
    
    local i=1
    for label in "${labels[@]}"; do
        printf "    \033[90m%2d)\033[0m %s\n" "$i" "$label"
        i=$((i+1))
    done
    
    echo ""
    echo -e "    \033[90mexamples:  1   1,3,5   all   1-3   dry 2,4   q\033[0m"
    read -p "  Select: " input
    
    [ -z "$input" ] && return
    [[ "$input" =~ ^[qQ]$ ]] && return
    
    if [[ "$input" == dry\ * ]]; then
        __clean_dry=1
        input="${input#dry }"
    fi
    
    if [ "$input" = "all" ]; then
        for opt in "${opts[@]}"; do
            case "$opt" in
                apt)         __clean_apt ;;
                docker)      __clean_docker shallow ;;
                docker-deep) ;;
                logs)        __clean_logs ;;
                journal)     __clean_journal ;;
                tmp)         __clean_tmp ;;
                snap)        __clean_snap ;;
                thumbnails)  __clean_thumbnails ;;
                trash)       __clean_trash ;;
            esac
        done
        __clean_show_freed
        return
    fi
    
    local picked=()
    
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | tr -d ' ')
        
        if [[ "$part" == *-* ]]; then
            local from=${part%-*}
            local to=${part#*-}
            for ((n=from; n<=to; n++)); do
                picked+=("$n")
            done
        else
            picked+=("$part")
        fi
    done
    
    for n in "${picked[@]}"; do
        if [[ ! "$n" =~ ^[0-9]+$ ]]; then
            echo "  invalid: $n"
            continue
        fi
        if [ "$n" -lt 1 ] || [ "$n" -gt "${#opts[@]}" ]; then
            echo "  out of range: $n"
            continue
        fi
        
        local opt="${opts[$((n-1))]}"
        case "$opt" in
            apt)         __clean_apt ;;
            docker)      __clean_docker shallow ;;
            docker-deep) __clean_docker deep ;;
            logs)        __clean_logs ;;
            journal)     __clean_journal ;;
            tmp)         __clean_tmp ;;
            snap)        __clean_snap ;;
            thumbnails)  __clean_thumbnails ;;
            trash)       __clean_trash ;;
        esac
    done
    
    __clean_show_freed
}

_clean_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "apt docker docker-deep logs journal tmp snap thumbnails trash all --dry -h" -- "$cur") )
}
complete -F _clean_complete clean