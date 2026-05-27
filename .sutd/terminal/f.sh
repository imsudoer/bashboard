#!/bin/bash

# :helpme:
# title: Fast Find
# desc: Find files by name, content, or age with sane shortcuts
# category: search
# usage:
#   f <pattern>                find files matching name in current dir
#   f <pattern> <dir>          find in specific directory
#   f -c "<text>"              grep content recursively
#   f -c "<text>" <dir>        grep content in specific dir
#   f -h <hours>               modified in last N hours
#   f -d <days>                modified in last N days
#   f -t f                     files only
#   f -t d                     directories only
#   f --help                   this help
# examples:
#   f config
#   f config /etc
#   f -c "DATABASE_URL"
#   f -c "TODO" src/
#   f -d 1
#   f -h 6 -t f
#   f -d 7 -t d
# :endhelpme:
f() {
    local dir="."
    local pattern=""
    local mode="name"
    local age=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--content)  mode="content"; pattern="$2"; shift 2 ;;
            -h|--hours)    age="-mmin -$(( ${2%h} * 60 ))"; shift 2 ;;
            -d|--days)     age="-mtime -${2%d}"; shift 2 ;;
            -t|--type)
                case "$2" in
                    f|file) age="$age -type f" ;;
                    d|dir)  age="$age -type d" ;;
                esac
                shift 2
                ;;
            --help)
                cat << 'EOF'
  f — fast file finder

  f <pattern>              find by name in current dir
  f <pattern> <dir>        find in specific dir
  f -c "<text>"            grep content
  f -c "<text>" <dir>      grep in dir
  f -h <hours>             modified in last N hours
  f -d <days>              modified in last N days
  f -t f|d                 type: file or directory
  f --help                 this help

  Examples:
    f config
    f config /etc
    f -c "DATABASE_URL"
    f -d 1 -t f
EOF
                return
                ;;
            *)
                if [ -z "$pattern" ] && [ "$mode" = "name" ]; then
                    pattern="$1"
                elif [ -d "$1" ]; then
                    dir="$1"
                fi
                shift
                ;;
        esac
    done
    
    if [ "$mode" = "content" ]; then
        [ -z "$pattern" ] && { echo "  usage: f -c \"text\""; return 1; }
        grep -rIn --color=auto $age "$pattern" "$dir" 2>/dev/null | head -50
    else
        if [ -n "$pattern" ]; then
            find "$dir" $age -iname "*${pattern}*" 2>/dev/null | head -50
        else
            find "$dir" $age 2>/dev/null | head -50
        fi
    fi
}