#!/bin/bash

# :helpme:
# title: What is this?
# desc: Universal "what is this thing" inspector for processes, ports, services, commands, files
# category: utility
# usage:
#   wat <pid>               process info by PID
#   wat :<port>             who listens on port
#   wat <command>           where command lives, version, type
#   wat <service>           systemctl status pretty
#   wat <file>              what is this file, who uses it
#   wat -h                  this help
# examples:
#   wat 1234
#   wat :8080
#   wat docker
#   wat nginx
#   wat /var/log/syslog
# :endhelpme:

wat() {
    local input="$1"
    
    if [ -z "$input" ]; then
        echo "  usage: wat <pid|:port|command|service|file>"
        return 1
    fi
    
    if [[ "$input" == ":"* ]]; then
        __wat_port "${input#:}"
        return
    fi
    
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        __wat_pid "$input"
        return
    fi
    
    if [ -e "$input" ]; then
        __wat_file "$input"
        return
    fi
    
    if systemctl list-unit-files "${input}.service" &>/dev/null && \
       systemctl cat "${input}.service" &>/dev/null; then
        __wat_service "$input"
        return
    fi
    
    if systemctl list-unit-files "$input" &>/dev/null && \
       systemctl cat "$input" &>/dev/null; then
        __wat_service "${input%.*}"
        return
    fi
    
    if command -v "$input" &>/dev/null; then
        __wat_command "$input"
        return
    fi
    
    echo -e "  \033[31m✗\033[0m no idea what '$input' is"
    echo "  tried: pid, port (with :), file, service, command"
    return 1
}

__wat_pid() {
    local pid="$1"
    
    if [ ! -d "/proc/$pid" ]; then
        echo -e "  \033[31m✗\033[0m no process with PID $pid"
        return 1
    fi
    
    local name=$(cat /proc/$pid/comm 2>/dev/null)
    local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
    local owner=$(stat -c '%U' /proc/$pid 2>/dev/null)
    local started=$(stat -c '%y' /proc/$pid 2>/dev/null | cut -d. -f1)
    local cwd=$(readlink /proc/$pid/cwd 2>/dev/null)
    local exe=$(readlink /proc/$pid/exe 2>/dev/null)
    local ppid=$(awk '/^PPid:/ {print $2}' /proc/$pid/status 2>/dev/null)
    local threads=$(awk '/^Threads:/ {print $2}' /proc/$pid/status 2>/dev/null)
    local mem=$(awk '/^VmRSS:/ {printf "%.1f MB", $2/1024}' /proc/$pid/status 2>/dev/null)
    
    echo -e "  \033[38;5;208m▸ Process $pid\033[0m"
    echo -e "    \033[37mname:\033[0m    $name"
    echo -e "    \033[37mowner:\033[0m   $owner"
    echo -e "    \033[37mcmd:\033[0m     ${cmdline:0:80}"
    echo -e "    \033[37mexe:\033[0m     $exe"
    echo -e "    \033[37mcwd:\033[0m     $cwd"
    echo -e "    \033[37mstarted:\033[0m $started"
    echo -e "    \033[37mppid:\033[0m    $ppid"
    echo -e "    \033[37mthreads:\033[0m $threads"
    echo -e "    \033[37mmemory:\033[0m  $mem"
    
    local open_files=$(ls /proc/$pid/fd 2>/dev/null | wc -l)
    echo -e "    \033[37mopen fd:\033[0m $open_files"
    
    local listening=$(ss -tlnpH 2>/dev/null | grep "pid=$pid," | awk '{print $4}' | head -5)
    if [ -n "$listening" ]; then
        echo -e "    \033[37mlistens:\033[0m"
        echo "$listening" | while read port; do
            echo -e "      \033[32m●\033[0m $port"
        done
    fi
    
    local connections=$(ss -tnpH 2>/dev/null | grep "pid=$pid," | awk '$1 == "ESTAB" {print $5}' | head -5)
    if [ -n "$connections" ]; then
        echo -e "    \033[37mconnected to:\033[0m"
        echo "$connections" | while read peer; do
            echo -e "      \033[38;5;75m→\033[0m $peer"
        done
    fi
    
    local children=$(pgrep -P "$pid" 2>/dev/null)
    if [ -n "$children" ]; then
        local count=$(echo "$children" | wc -l)
        echo -e "    \033[37mchildren:\033[0m $count"
    fi
}

__wat_port() {
    local port="$1"
    
    local result=$(ss -tlnpH 2>/dev/null | awk -v p=":$port" '$4 ~ p"$"')
    
    if [ -z "$result" ]; then
        result=$(ss -ulnpH 2>/dev/null | awk -v p=":$port" '$4 ~ p"$"')
    fi
    
    if [ -z "$result" ]; then
        echo -e "  \033[33m⚠\033[0m nothing listening on port $port"
        local proc_using=$(ss -tnpH 2>/dev/null | awk -v p=":$port" '$5 ~ p' | head -3)
        if [ -n "$proc_using" ]; then
            echo -e "  \033[37mbut these have outgoing connections to that port:\033[0m"
            echo "$proc_using" | awk '{print "    "$5"  "$NF}'
        fi
        return 1
    fi
    
    echo -e "  \033[38;5;208m▸ Port $port\033[0m"
    
    echo "$result" | while read line; do
        local bind=$(echo "$line" | awk '{print $4}')
        local proc_info=$(echo "$line" | grep -oP 'users:$$"[^"]+","pid=\d+' | head -1)
        local pname=$(echo "$proc_info" | sed -E 's/.*"([^"]+)".*/\1/')
        local ppid=$(echo "$proc_info" | grep -oP 'pid=\K\d+')
        
        echo -e "    \033[37mlistening:\033[0m $bind"
        echo -e "    \033[37mprocess:\033[0m   $pname (pid $ppid)"
        
        if [ -n "$ppid" ]; then
            local cmdline=$(tr '\0' ' ' < /proc/$ppid/cmdline 2>/dev/null)
            local owner=$(stat -c '%U' /proc/$ppid 2>/dev/null)
            echo -e "    \033[37mowner:\033[0m     $owner"
            echo -e "    \033[37mcmdline:\033[0m   ${cmdline:0:70}"
        fi
    done
    
    local established=$(ss -tnpH 2>/dev/null | awk -v p=":$port" '$1 == "ESTAB" && $4 ~ p"$" {print $5}' | sort -u | head -10)
    if [ -n "$established" ]; then
        local conn_count=$(echo "$established" | wc -l)
        echo -e "    \033[37mconnections:\033[0m $conn_count active"
        echo "$established" | head -5 | while read peer; do
            echo -e "      \033[38;5;75m→\033[0m $peer"
        done
    fi
}

__wat_command() {
    local cmd="$1"
    local cmd_type=$(type -t "$cmd")
    local cmd_path=$(command -v "$cmd")
    
    echo -e "  \033[38;5;208m▸ Command '$cmd'\033[0m"
    echo -e "    \033[37mtype:\033[0m     $cmd_type"
    echo -e "    \033[37mpath:\033[0m     $cmd_path"
    
    case "$cmd_type" in
        alias)
            local def=$(alias "$cmd" 2>/dev/null | sed -E "s/^alias [^=]+='(.*)'$/\1/")
            echo -e "    \033[37mdefined:\033[0m $def"
            ;;
        function)
            local source_info=$(declare -F "$cmd" 2>/dev/null)
            shopt -s extdebug
            local fn_info=$(declare -F "$cmd" 2>/dev/null)
            shopt -u extdebug
            echo -e "    \033[37mfunction in:\033[0m use 'declare -f $cmd' to inspect"
            ;;
        builtin)
            echo -e "    \033[37minfo:\033[0m    shell builtin (try: help $cmd)"
            ;;
        file)
            if [ -L "$cmd_path" ]; then
                local target=$(readlink -f "$cmd_path")
                echo -e "    \033[37msymlink to:\033[0m $target"
                cmd_path="$target"
            fi
            
            local file_type=$(file -b "$cmd_path" 2>/dev/null | cut -c1-60)
            echo -e "    \033[37mfile:\033[0m    $file_type"
            
            local size=$(stat -c '%s' "$cmd_path" 2>/dev/null)
            if [ -n "$size" ]; then
                local human_size
                if [ "$size" -gt 1048576 ]; then
                    human_size="$((size/1048576)) MB"
                elif [ "$size" -gt 1024 ]; then
                    human_size="$((size/1024)) KB"
                else
                    human_size="${size} B"
                fi
                echo -e "    \033[37msize:\033[0m    $human_size"
            fi
            
            local owner_pkg
            if command -v dpkg &>/dev/null; then
                owner_pkg=$(dpkg -S "$cmd_path" 2>/dev/null | cut -d: -f1 | head -1)
            elif command -v rpm &>/dev/null; then
                owner_pkg=$(rpm -qf "$cmd_path" 2>/dev/null | head -1)
            fi
            [ -n "$owner_pkg" ] && echo -e "    \033[37mpackage:\033[0m $owner_pkg"
            
            for flag in --version -V -v; do
                local version_out=$(timeout 2 "$cmd_path" "$flag" 2>&1 | head -1)
                if [ -n "$version_out" ] && [ "${#version_out}" -lt 100 ]; then
                    echo -e "    \033[37mversion:\033[0m $version_out"
                    break
                fi
            done
            
            local running_count=$(pgrep -c "^${cmd}$" 2>/dev/null)
            [ "${running_count:-0}" -gt 0 ] && echo -e "    \033[37mrunning:\033[0m $running_count instance(s)"
            ;;
    esac
}

__wat_service() {
    local svc="$1"
    
    local state=$(systemctl is-active "$svc" 2>/dev/null)
    local enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
    local desc=$(systemctl show "$svc" -p Description --value 2>/dev/null)
    local fragment=$(systemctl show "$svc" -p FragmentPath --value 2>/dev/null)
    local main_pid=$(systemctl show "$svc" -p MainPID --value 2>/dev/null)
    local active_since=$(systemctl show "$svc" -p ActiveEnterTimestamp --value 2>/dev/null)
    
    local state_color="$COLOR_GRAY"
    case "$state" in
        active)   state_color="\033[32m" ;;
        inactive) state_color="\033[33m" ;;
        failed)   state_color="\033[31m" ;;
    esac
    
    echo -e "  \033[38;5;208m▸ Service $svc\033[0m"
    echo -e "    \033[37mstate:\033[0m   ${state_color}${state}\033[0m"
    echo -e "    \033[37menabled:\033[0m $enabled"
    echo -e "    \033[37mdesc:\033[0m    $desc"
    echo -e "    \033[37munit:\033[0m    $fragment"
    
    if [ "$main_pid" != "0" ] && [ -n "$main_pid" ]; then
        echo -e "    \033[37mmain pid:\033[0m $main_pid"
    fi
    
    if [ -n "$active_since" ] && [ "$active_since" != "n/a" ]; then
        echo -e "    \033[37msince:\033[0m   $active_since"
    fi
    
    local mem=$(systemctl show "$svc" -p MemoryCurrent --value 2>/dev/null)
    if [ -n "$mem" ] && [ "$mem" != "[not set]" ] && [ "$mem" -gt 0 ] 2>/dev/null; then
        local mem_h
        if [ "$mem" -gt 1048576 ]; then
            mem_h="$((mem/1048576)) MB"
        else
            mem_h="$((mem/1024)) KB"
        fi
        echo -e "    \033[37mmemory:\033[0m  $mem_h"
    fi
    
    echo ""
    echo -e "    \033[37mrecent log:\033[0m"
    journalctl -u "$svc" -n 5 --no-pager 2>/dev/null | tail -5 | while read line; do
        echo "      $line"
    done
}

__wat_file() {
    local path="$1"
    local full_path=$(realpath "$path" 2>/dev/null || echo "$path")
    
    echo -e "  \033[38;5;208m▸ Path $full_path\033[0m"
    
    if [ -L "$path" ]; then
        local link_target=$(readlink "$path")
        echo -e "    \033[37mtype:\033[0m    symlink → $link_target"
    elif [ -d "$path" ]; then
        echo -e "    \033[37mtype:\033[0m    directory"
        local files_count=$(ls "$path" 2>/dev/null | wc -l)
        echo -e "    \033[37mentries:\033[0m $files_count"
        local total_size=$(du -sh "$path" 2>/dev/null | cut -f1)
        echo -e "    \033[37msize:\033[0m    $total_size"
    elif [ -f "$path" ]; then
        local file_type=$(file -b "$path" 2>/dev/null | cut -c1-70)
        echo -e "    \033[37mtype:\033[0m    $file_type"
        
        local size=$(stat -c '%s' "$path" 2>/dev/null)
        local size_h
        if [ "$size" -gt 1048576 ]; then
            size_h="$((size/1048576)) MB"
        elif [ "$size" -gt 1024 ]; then
            size_h="$((size/1024)) KB"
        else
            size_h="${size} B"
        fi
        echo -e "    \033[37msize:\033[0m    $size_h"
        
        local lines=$(wc -l < "$path" 2>/dev/null)
        [ -n "$lines" ] && [ "$lines" -gt 0 ] && echo -e "    \033[37mlines:\033[0m   $lines"
    fi
    
    local owner=$(stat -c '%U:%G' "$path" 2>/dev/null)
    local perms=$(stat -c '%A (%a)' "$path" 2>/dev/null)
    local modified=$(stat -c '%y' "$path" 2>/dev/null | cut -d. -f1)
    
    echo -e "    \033[37mowner:\033[0m   $owner"
    echo -e "    \033[37mperms:\033[0m   $perms"
    echo -e "    \033[37mmodified:\033[0m $modified"
    
    if command -v lsof &>/dev/null; then
        local users=$(lsof "$path" 2>/dev/null | tail -n +2 | head -5)
        if [ -n "$users" ]; then
            echo ""
            echo -e "    \033[37mopen by:\033[0m"
            echo "$users" | while read line; do
                local pname=$(echo "$line" | awk '{print $1}')
                local ppid=$(echo "$line" | awk '{print $2}')
                local puser=$(echo "$line" | awk '{print $3}')
                printf "      \033[38;5;75m●\033[0m %-15s pid=%-6s user=%s\n" "$pname" "$ppid" "$puser"
            done
        fi
    fi
}

_wat_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    
    if [[ "$cur" == ":"* ]]; then
        local ports=$(ss -tlnH 2>/dev/null | awk '{print $4}' | sed -E 's/.*:([0-9]+)$/:\1/' | sort -u)
        COMPREPLY=( $(compgen -W "$ports" -- "$cur") )
    elif [[ "$cur" =~ ^[0-9] ]]; then
        local pids=$(ps -eo pid --no-headers 2>/dev/null)
        COMPREPLY=( $(compgen -W "$pids" -- "$cur") )
    else
        COMPREPLY=( $(compgen -c -- "$cur") $(compgen -f -- "$cur") )
    fi
}
complete -F _wat_complete wat