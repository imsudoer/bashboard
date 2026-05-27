#!/bin/bash

proc() {
    local pattern=""
    local action="list"
    local sort_by="cpu"
    local user=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -k|--kill)    action="kill"; shift ;;
            -t|--tree)    action="tree"; shift ;;
            -m|--mem)     sort_by="mem"; shift ;;
            -u|--user)    user="$2"; shift 2 ;;
            -h|--help)
                cat << 'EOF'
  proc — find and manage processes

  proc <pattern>            list processes matching name
  proc -m <pattern>         sort by memory instead of CPU
  proc -u <user> <pattern>  filter by user
  proc -t <pattern>         tree view
  proc -k <pattern>         kill matching processes (with confirm)
  proc -h                   this help
EOF
                return
                ;;
            *) pattern="$1"; shift ;;
        esac
    done
    
    [ -z "$pattern" ] && { echo "  usage: proc <pattern>"; return 1; }
    
    case "$action" in
        tree)
            if command -v pstree &>/dev/null; then
                pstree -p | grep -i --color=always -A1 -B1 "$pattern"
            else
                ps -ef --forest | grep -i --color=always "$pattern"
            fi
            return
            ;;
    esac
    
    local sort_field
    [ "$sort_by" = "mem" ] && sort_field="-%mem" || sort_field="-%cpu"
    
    local user_filter=""
    [ -n "$user" ] && user_filter="-U $user"
    
    local pids=()
    
    echo -e "  \033[37mProcesses matching '\033[38;5;208m$pattern\033[37m':\033[0m"
    echo -e "  \033[90m  PID     %CPU   %MEM   USER          COMMAND\033[0m"
    
    while read pid pcpu pmem puser pcmd; do
        [ -z "$pid" ] && continue
        pids+=("$pid")
        
        local cpu_color="\033[37m"
        local mem_color="\033[37m"
        
        local cpu_int=${pcpu%.*}
        local mem_int=${pmem%.*}
        
        [ "${cpu_int:-0}" -gt 50 ] && cpu_color="\033[33m"
        [ "${cpu_int:-0}" -gt 80 ] && cpu_color="\033[31m"
        [ "${mem_int:-0}" -gt 50 ] && mem_color="\033[33m"
        [ "${mem_int:-0}" -gt 80 ] && mem_color="\033[31m"
        
        printf "    %-7s ${cpu_color}%5s%%\033[0m  ${mem_color}%5s%%\033[0m  %-13s %s\n" \
            "$pid" "$pcpu" "$pmem" "$puser" "$pcmd"
    done < <(ps $user_filter -eo pid,pcpu,pmem,user,comm --sort=$sort_field --no-headers 2>/dev/null \
              | grep -i "$pattern" \
              | grep -v "proc $pattern" \
              | head -20)
    
    if [ ${#pids[@]} -eq 0 ]; then
        echo -e "  \033[90m  (no matches)\033[0m"
        return
    fi
    
    echo -e "  \033[90m  ${#pids[@]} match(es)\033[0m"
    
    if [ "$action" = "kill" ]; then
        echo ""
        read -p "  Kill these ${#pids[@]} processes? [y/N/9 (force)]: " ans
        case "$ans" in
            y|Y) kill "${pids[@]}" 2>/dev/null && echo -e "  \033[32m✓\033[0m sent SIGTERM" ;;
            9)   kill -9 "${pids[@]}" 2>/dev/null && echo -e "  \033[31m✗\033[0m sent SIGKILL" ;;
            *)   echo "  cancelled" ;;
        esac
    fi
}

_proc_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "-k -t -m -u --kill --tree --mem --user -h" -- "$cur") )
}
complete -F _proc_complete proc