#!/bin/bash

compress() {
    local source=""
    local format="tar.gz"
    local password=""
    local excludes=()
    local output=""
    local ask_password=0
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -z|--zip)     format="zip"; shift ;;
            -7|--7z)      format="7z"; shift ;;
            -t|--tar)     format="tar.gz"; shift ;;
            -b|--tarbz2)  format="tar.bz2"; shift ;;
            -x|--tarxz)   format="tar.xz"; shift ;;
            -p|--password) ask_password=1; shift ;;
            -e|--exclude)
                shift
                while [ $# -gt 0 ] && [[ "$1" != -* ]]; do
                    excludes+=("$1")
                    shift
                done
                ;;
            -o|--output) output="$2"; shift 2 ;;
            -h|--help)
                cat << 'EOF'
  compress — universal archiver

  compress <source>                tar.gz (default)
  compress -z <source>             zip
  compress -7 <source>             7z
  compress -b <source>             tar.bz2
  compress -x <source>             tar.xz
  compress -p <source>             prompt for password (7z/zip only)
  compress -o <name> <source>      custom output name
  compress -e f1 f2 <source>       exclude files/patterns
  compress -h                      this help

  Examples:
    compress myproject
    compress -z myproject -o backup.zip
    compress -7 -p secrets/
    compress backups/ -e "*.log" "*.tmp"
EOF
                return
                ;;
            *)
                if [ -z "$source" ]; then source="$1"; fi
                shift
                ;;
        esac
    done
    
    [ -z "$source" ] && { echo "  usage: compress <source>"; return 1; }
    [ ! -e "$source" ] && { echo "  no such file/dir: $source"; return 1; }
    
    local base
    base=$(basename "$source")
    base="${base%/}"
    
    [ -z "$output" ] && output="${base}.${format}"
    
    if [ "$ask_password" = "1" ]; then
        read -sp "  Password: " password
        echo ""
        [ -z "$password" ] && { echo "  empty password, aborted"; return 1; }
    fi
    
    echo -e "  \033[90m→\033[0m archiving $source to $output"
    
    case "$format" in
        tar.gz)
            local args=()
            for e in "${excludes[@]}"; do
                args+=(--exclude="$e")
            done
            if command -v pv &>/dev/null; then
                local size
                size=$(du -sb "$source" 2>/dev/null | awk '{print $1}')
                tar cf - "${args[@]}" "$source" 2>/dev/null | pv -s "$size" | gzip > "$output"
            else
                tar czvf "$output" "${args[@]}" "$source" 2>&1 | tail -5
            fi
            ;;
        tar.bz2)
            local args=()
            for e in "${excludes[@]}"; do args+=(--exclude="$e"); done
            tar cjvf "$output" "${args[@]}" "$source" 2>&1 | tail -5
            ;;
        tar.xz)
            local args=()
            for e in "${excludes[@]}"; do args+=(--exclude="$e"); done
            tar cJvf "$output" "${args[@]}" "$source" 2>&1 | tail -5
            ;;
        zip)
            command -v zip &>/dev/null || { echo "  zip not installed"; return 1; }
            local args=()
            for e in "${excludes[@]}"; do args+=(-x "$e"); done
            if [ -n "$password" ]; then
                zip -r -P "$password" "$output" "$source" "${args[@]}" 2>&1 | tail -3
            else
                zip -r "$output" "$source" "${args[@]}" 2>&1 | tail -3
            fi
            ;;
        7z)
            command -v 7z &>/dev/null || { echo "  7z not installed (apt install p7zip-full)"; return 1; }
            local args=()
            for e in "${excludes[@]}"; do args+=("-x!$e"); done
            if [ -n "$password" ]; then
                7z a -p"$password" -mhe=on "$output" "$source" "${args[@]}" 2>&1 | tail -3
            else
                7z a "$output" "$source" "${args[@]}" 2>&1 | tail -3
            fi
            ;;
        *)
            echo "  unknown format: $format"
            return 1
            ;;
    esac
    
    if [ -f "$output" ]; then
        local size
        size=$(du -h "$output" | cut -f1)
        echo -e "  \033[32m✓\033[0m created: $output \033[90m($size)\033[0m"
    else
        echo -e "  \033[31m✗\033[0m archive not created"
        return 1
    fi
}

_compress_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-z -7 -t -b -x -p -e -o -h --zip --7z --tar --tarbz2 --tarxz --password --exclude --output --help" -- "$cur") )
    else
        COMPREPLY=( $(compgen -f -- "$cur") )
    fi
}
complete -F _compress_complete compress